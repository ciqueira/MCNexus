using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.IO.Pipes;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;
using Microsoft.Win32;
using Microsoft.Win32.SafeHandles;
using System.Windows.Media.Imaging;

namespace MCAppsTools
{
    public partial class App : Application
    {
        private const uint ImageIcon = 1;
        private const uint LoadFromFile = 0x0010;
        private const int WmSetIcon = 0x0080;
        private const int IconSmall = 0;
        private const int IconBig = 1;
        private const string AppUserModelId = "MagnoCiqueira.MCNexus";
        private const string ElevatedRelaunchArgument = "--elevated-relaunch";
        private const int ErrorCancelled = 1223;

        // Backlog item 4 — deep link routing (§2.1/§2.2 of the plan).
        // No explicit Local\/Global\ prefix: both the medium-integrity shell
        // launch and the already-running elevated instance live in the SAME
        // interactive session (UAC elevation via consent.exe never switches
        // sessions), so the default session-local namespace already covers
        // it — no SeCreateGlobalPrivilege needed.
        private const string SingleInstanceMutexName = "MagnoCiqueira.MCNexus.SingleInstance";
        private const string DeepLinkPipeName = "MagnoCiqueira.MCNexus.DeepLink";
        private const string DeepLinkArgumentPrefix = "mcnexus://";
        private static readonly TimeSpan PipeForwardTimeout = TimeSpan.FromSeconds(3);

        public static bool IsExplicitShutdown { get; set; }
        private MCAppsTools.Services.TrayIconService? _trayIconService;
        private bool _isUserPreferenceChangedSubscribed;
        private IntPtr _smallThemeIconHandle;
        private IntPtr _largeThemeIconHandle;
        private MainWindow? _elevationRequiredWindow;
        private Mutex? _singleInstanceMutex;
        private CancellationTokenSource? _pipeServerCancellation;
        // Read by TryRestartElevated(), including on a later "Try Again"
        // click — set once, at the top of this process's own OnStartup, so a
        // retry (same process, same App instance) still carries the link
        // that triggered the original elevation attempt.
        private string? _pendingDeepLinkArgument;

        protected override void OnStartup(StartupEventArgs e)
        {
            base.OnStartup(e);

            // Register error handling before attempting elevation so launch failures
            // are always presented to the user instead of closing the process.
            DispatcherUnhandledException += App_DispatcherUnhandledException;
            TaskScheduler.UnobservedTaskException += TaskScheduler_UnobservedTaskException;
            AppDomain.CurrentDomain.UnhandledException += CurrentDomain_UnhandledException;

            var appUserModelResult = SetCurrentProcessExplicitAppUserModelID(AppUserModelId);
            if (appUserModelResult != 0)
            {
                System.Diagnostics.Debug.WriteLine($"[AppUserModelID] Could not set {AppUserModelId}. HRESULT: 0x{appUserModelResult:X8}");
            }

            // Extracted once, up front: this same line re-finds the link
            // after an elevated relaunch too, since TryRestartElevated below
            // passes it straight through as a second command-line argument.
            var deepLinkArgument = e.Args.FirstOrDefault(IsValidDeepLinkArgument);
            _pendingDeepLinkArgument = deepLinkArgument;

            if (IsRunningAsAdministrator())
            {
                // The single-instance mutex is claimed ONLY here, by the
                // process that actually becomes the long-running app — never
                // by the medium-integrity launcher below. That keeps the
                // elevation handoff from racing against mutex ownership: the
                // launcher exits almost immediately after spawning this
                // process, so a mutex it held itself could still be
                // held-but-about-to-be-released when this process asks.
                if (!TryClaimSingleInstance())
                {
                    ForwardToRunningInstance(deepLinkArgument);
                    Shutdown();
                    return;
                }

                OpenMainWindow();
                StartDeepLinkPipeServer();
                MCAppsTools.Services.NexControlBridge.Start();
                if (deepLinkArgument is not null)
                {
                    RouteForwardedLine(deepLinkArgument);
                }
                return;
            }

            if (e.Args.Contains(ElevatedRelaunchArgument, StringComparer.OrdinalIgnoreCase))
            {
                ShowElevationRequiredWindow(
                    "MCNexus could not restart with administrator permission.");
                return;
            }

            // Ask before paying for a UAC prompt: if an elevated instance
            // already exists, forward instead of elevating a second one.
            // This is a probe, not a claim, and it is racy by nature — two
            // near-simultaneous launches before either has created the mutex
            // can both proceed to elevate. Accepted: the same race exists in
            // most single-instance Windows apps that also self-elevate, and
            // narrowing it further needs cross-process coordination this
            // app has no other use for.
            if (SingleInstanceMutexExists())
            {
                ForwardToRunningInstance(deepLinkArgument);
                Shutdown();
                return;
            }

            TryRestartElevated();
        }

        protected override void OnExit(ExitEventArgs e)
        {
            if (_isUserPreferenceChangedSubscribed)
            {
                SystemEvents.UserPreferenceChanged -= SystemEvents_UserPreferenceChanged;
            }

            _pipeServerCancellation?.Cancel();
            try
            {
                _singleInstanceMutex?.ReleaseMutex();
            }
            catch (ApplicationException)
            {
                // Not owned by this thread, or already released — fine on shutdown.
            }
            _singleInstanceMutex?.Dispose();

            ReleaseNativeThemeIcons();
            _trayIconService?.Dispose();
            _trayIconService = null;
            MCAppsTools.Services.NexControlBridge.Stop();
            base.OnExit(e);
        }

        private void App_DispatcherUnhandledException(object sender, DispatcherUnhandledExceptionEventArgs e)
        {
            ShowCrashMessage(e.Exception, "UI Thread");
            e.Handled = true; // Prevent the app from closing
        }

        private void TaskScheduler_UnobservedTaskException(object? sender, UnobservedTaskExceptionEventArgs e)
        {
            // Usually we don't show a message box for background tasks, but we log it.
            System.Diagnostics.Debug.WriteLine($"[Unobserved Task Error] {e.Exception}");
            e.SetObserved();
        }

        private void CurrentDomain_UnhandledException(object sender, UnhandledExceptionEventArgs e)
        {
            if (e.ExceptionObject is Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Fatal Error] {ex}");
                // Can't easily recover from a corrupted state in CurrentDomain, but we try to prevent an instant silent close.
                MessageBox.Show($"A fatal error occurred: {ex.Message}\n\nPlease restart the application.", "MCNexus Fatal Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private static void ShowCrashMessage(Exception ex, string context)
        {
            System.Diagnostics.Debug.WriteLine($"[Crash Prevented - {context}] {ex}");
            MessageBox.Show($"An unexpected error occurred: {ex.Message}", "MCNexus Error", MessageBoxButton.OK, MessageBoxImage.Warning);
        }

        private void OpenMainWindow()
        {
            SetAppIconForTheme();
            TrySubscribeToThemeChanges();

            _trayIconService = new MCAppsTools.Services.TrayIconService(IsLightThemeEnabled());
            _trayIconService.Initialize();

            var window = new MainWindow();
            MainWindow = window;
            ShutdownMode = ShutdownMode.OnExplicitShutdown;
            window.Show();

            CancellationTokenSource? networkDebounceCts = null;
            System.Net.NetworkInformation.NetworkChange.NetworkAvailabilityChanged += (s, e) =>
            {
                networkDebounceCts?.Cancel();
                networkDebounceCts?.Dispose();
                networkDebounceCts = null;

                if (!e.IsAvailable)
                {
                    // Immediate pause on physical network loss (Lacuna B)
                    Current?.Dispatcher.Invoke(() =>
                    {
                        if (Current?.MainWindow is MainWindow win && win.DataContext is MainWindowViewModel vm)
                        {
                            vm.IsNetworkAvailable = false;
                            vm.PauseBackgroundTimers();
                        }
                    });
                    return;
                }
                // Debounce of 10s strictly for reconnection to allow DHCP/DNS stabilization
                // Debounce of 10s strictly for reconnection to allow DHCP/DNS stabilization
                networkDebounceCts = new CancellationTokenSource();
                var token = networkDebounceCts.Token;

                Task.Delay(10000, token).ContinueWith(t =>
                {
                    if (t.IsCanceled)
                    {
                        return;
                    }

                    Current?.Dispatcher.Invoke(() =>
                    {
                        if (Current?.MainWindow is MainWindow win && win.DataContext is MainWindowViewModel vm)
                        {
                            vm.IsNetworkAvailable = true;
                            if (win.IsVisible && win.WindowState != WindowState.Minimized)
                            {
                                vm.ResumeBackgroundTimers();
                            }
                        }
                    });
                }, TaskScheduler.Default);
            };
        }

        public static void OpenOrRestoreMainWindow()
        {
            if (Current is not App app)
            {
                return;
            }

            if (app.MainWindow is MainWindow window)
            {
                if (!window.IsVisible)
                {
                    window.Show();
                }
                if (window.WindowState == WindowState.Minimized)
                {
                    window.WindowState = WindowState.Normal;
                }
                window.Activate();
                (window.DataContext as MainWindowViewModel)?.ResumeBackgroundTimers();
            }
            else
            {
                var newWin = new MainWindow();
                app.MainWindow = newWin;
                newWin.Show();
            }
        }

        public static void QuitApplication()
        {
            IsExplicitShutdown = true;
            if (Current is App app)
            {
                app._trayIconService?.Dispose();
                app._trayIconService = null;
            }
            Current.Shutdown();
        }

        // ── Backlog item 4 — single instance + deep link forwarding ────────
        //
        // Two processes can legitimately want to be "the app" in sequence: a
        // medium-integrity launcher (whatever invoked mcnexus://, e.g. a
        // shell URL activation) and the elevated instance it spawns via UAC.
        // Only the elevated one is allowed to become the long-running app —
        // see the comment on SingleInstanceMutexName above for why no
        // explicit Local\/Global\ prefix is needed.

        /// <summary>
        /// Claims the single-instance mutex for this process's whole
        /// lifetime. Called ONLY from the already-elevated branch of
        /// OnStartup — the launcher never owns this mutex, so there is no
        /// handoff race to resolve when it exits.
        /// </summary>
        private bool TryClaimSingleInstance()
        {
            try
            {
                _singleInstanceMutex = new Mutex(initiallyOwned: true, SingleInstanceMutexName, out var createdNew);
                return createdNew;
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[SingleInstance] Could not claim the instance mutex: {ex}");
                // Fail open: refusing to start at all is worse than the rare
                // risk of two elevated instances when mutex creation itself
                // is broken (e.g. a hardened environment blocking named
                // kernel objects).
                return true;
            }
        }

        /// <summary>
        /// A non-owning probe used by the medium-integrity launcher to
        /// decide whether to elevate at all.
        /// </summary>
        private static bool SingleInstanceMutexExists()
        {
            try
            {
                if (Mutex.TryOpenExisting(SingleInstanceMutexName, out var existing))
                {
                    existing.Dispose();
                    return true;
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[SingleInstance] Probe failed, assuming no running instance: {ex}");
            }
            return false;
        }

        /// <summary>
        /// Forwards to the running elevated instance's pipe — a real URI, or
        /// an empty line when this launch carried none, which still means
        /// something: bring the existing window forward, the same outcome a
        /// plain icon relaunch gets on most single-instance Windows apps.
        /// There is nothing safe to retry on failure: it means the running
        /// instance's pipe server is not listening (still starting up, or
        /// gone), and retrying risks racing a second elevation instead. A
        /// link that failed to forward is simply dropped — the same
        /// "nothing happens" outcome as one opened with no app installed.
        /// </summary>
        private static void ForwardToRunningInstance(string? deepLinkArgument)
        {
            try
            {
                using var client = new NamedPipeClientStream(".", DeepLinkPipeName, PipeDirection.Out);
                client.Connect((int)PipeForwardTimeout.TotalMilliseconds);
                using var writer = new StreamWriter(client) { AutoFlush = true };
                writer.WriteLine(deepLinkArgument ?? string.Empty);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[DeepLink] Could not forward to the running instance: {ex}");
            }
        }

        /// <summary>
        /// Starts the background listener the medium-integrity launcher
        /// forwards into. Must be called only after OpenMainWindow — it
        /// dispatches straight to MainWindow.HandleDeepLink.
        /// </summary>
        private void StartDeepLinkPipeServer()
        {
            _pipeServerCancellation = new CancellationTokenSource();
            _ = Task.Run(() => RunDeepLinkPipeServerAsync(_pipeServerCancellation.Token));
        }

        private async Task RunDeepLinkPipeServerAsync(CancellationToken cancellationToken)
        {
            System.Diagnostics.Debug.WriteLine("[DeepLink] Pipe server starting.");

            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    using var server = CreateDeepLinkPipeServer();

                    System.Diagnostics.Debug.WriteLine("[DeepLink] Pipe server listening.");
                    await server.WaitForConnectionAsync(cancellationToken).ConfigureAwait(false);

                    using var reader = new StreamReader(server);
                    var line = await reader.ReadLineAsync().ConfigureAwait(false);
                    if (line is not null)
                    {
                        RouteForwardedLine(line);
                    }
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"[DeepLink] Pipe server iteration failed: {ex}");
                    try
                    {
                        // Backoff so a persistent failure (e.g. a name
                        // collision that never clears) does not spin the loop.
                        await Task.Delay(1000, cancellationToken).ConfigureAwait(false);
                    }
                    catch (OperationCanceledException)
                    {
                        break;
                    }
                }
            }
        }

        /// <summary>
        /// This instance runs elevated, so objects it creates are labelled
        /// High integrity by default — which blocks writes from the
        /// medium-integrity process a plain shell URL activation actually
        /// runs as (Mandatory Integrity Control, not the DACL below). An
        /// explicit Medium mandatory label with no restriction removes that
        /// ceiling and is the part that actually fixes delivery — but
        /// WRITING a SACL entry (which a mandatory label technically is)
        /// requires SeSecurityPrivilege to be ENABLED on the current
        /// thread, and an elevated Administrator token carries that
        /// privilege DISABLED by default. Skipping this step is exactly
        /// what silently killed the whole listener before it ever started.
        ///
        /// Defensive on purpose: if enabling the privilege or setting the
        /// label fails for any reason this has not anticipated, the pipe
        /// still comes up with the plain DACL — reachable at least from
        /// same-or-higher integrity, and diagnosable via the log line below
        /// instead of dying with no trace.
        /// </summary>
        private const uint PipeAccessInbound = 0x00000001;
        private const uint FileFlagOverlapped = 0x40000000;
        private const uint PipeTypeByte = 0x00000000;
        private const uint PipeReadmodeByte = 0x00000000;
        private const uint PipeWait = 0x00000000;
        private const uint SddlRevision1 = 1;

        // Same SDDL proven in NexControlHub.cpp: grants Authenticated Users
        // write + read-attributes + synchronize (0x0012019B), Admins/SYSTEM
        // full control, and sets a Medium Mandatory Label at creation time
        // so medium-integrity forwarders (shell, PowerShell, DaVinci Resolve)
        // can connect to this elevated instance.
        private const string DeepLinkPipeSddl =
            "D:(A;;0x0012019B;;;AU)(A;;GA;;;BA)(A;;GA;;;SY)S:(ML;;;;;ME)";

        [StructLayout(LayoutKind.Sequential)]
        private struct SECURITY_ATTRIBUTES
        {
            public int nLength;
            public IntPtr lpSecurityDescriptor;
            [MarshalAs(UnmanagedType.Bool)]
            public bool bInheritHandle;
        }

        private static NamedPipeServerStream CreateDeepLinkPipeServer()
        {
            var securityDescriptor = IntPtr.Zero;
            try
            {
                if (ConvertStringSecurityDescriptorToSecurityDescriptorW(
                        DeepLinkPipeSddl,
                        SddlRevision1,
                        out securityDescriptor,
                        IntPtr.Zero))
                {
                    var sa = new SECURITY_ATTRIBUTES
                    {
                        nLength = Marshal.SizeOf<SECURITY_ATTRIBUTES>(),
                        lpSecurityDescriptor = securityDescriptor,
                        bInheritHandle = false
                    };

                    var rawHandle = CreateNamedPipeW(
                        @"\\.\pipe\" + DeepLinkPipeName,
                        PipeAccessInbound | FileFlagOverlapped,
                        PipeTypeByte | PipeReadmodeByte | PipeWait,
                        1,
                        0,
                        0,
                        0,
                        ref sa);

                    if (rawHandle != IntPtr.Zero && rawHandle != new IntPtr(-1))
                    {
                        var safeHandle = new SafePipeHandle(rawHandle, ownsHandle: true);
                        try
                        {
                            return new NamedPipeServerStream(
                                PipeDirection.In,
                                isAsync: true,
                                isConnected: false,
                                safeHandle);
                        }
                        catch
                        {
                            safeHandle.Dispose();
                            throw;
                        }
                    }

                    System.Diagnostics.Debug.WriteLine(
                        $"[DeepLink] CreateNamedPipeW with SDDL failed: {Marshal.GetLastWin32Error()}");
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[DeepLink] Native pipe creation failed, falling back to managed ACL: {ex}");
            }
            finally
            {
                if (securityDescriptor != IntPtr.Zero)
                {
                    LocalFree(securityDescriptor);
                }
            }

            var fallbackSecurity = new PipeSecurity();
            fallbackSecurity.AddAccessRule(new PipeAccessRule(
                new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null),
                PipeAccessRights.Write | PipeAccessRights.ReadAttributes | PipeAccessRights.Synchronize,
                AccessControlType.Allow));
            fallbackSecurity.AddAccessRule(new PipeAccessRule(
                new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
                PipeAccessRights.FullControl,
                AccessControlType.Allow));

            return NamedPipeServerStreamAcl.Create(
                DeepLinkPipeName,
                PipeDirection.In,
                maxNumberOfServerInstances: 1,
                PipeTransmissionMode.Byte,
                PipeOptions.Asynchronous,
                inBufferSize: 0,
                outBufferSize: 0,
                fallbackSecurity);
        }

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(
            string stringSecurityDescriptor,
            uint stringSDRevision,
            out IntPtr securityDescriptor,
            IntPtr securityDescriptorSize);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern IntPtr CreateNamedPipeW(
            string lpName,
            uint dwOpenMode,
            uint dwPipeMode,
            uint nMaxInstances,
            uint nOutBufferSize,
            uint nInBufferSize,
            uint nDefaultTimeOut,
            ref SECURITY_ATTRIBUTES lpSecurityAttributes);

        [DllImport("kernel32.dll", SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern IntPtr LocalFree(IntPtr hMem);

        /// <summary>
        /// A blank line is a real, distinct message — "bring the window
        /// forward, no link attached" — not a malformed one; only a non-blank
        /// line that fails to parse as an `mcnexus://` URI is dropped as
        /// garbage. Safe to call from either the pipe server's background
        /// thread or directly from OnStartup on the main thread —
        /// Dispatcher.Invoke does not deadlock when already on its own
        /// thread.
        /// </summary>
        private void RouteForwardedLine(string line)
        {
            if (string.IsNullOrWhiteSpace(line))
            {
                Dispatcher.Invoke(() =>
                {
                    if (MainWindow is MainWindow window)
                    {
                        window.ActivateFromSecondInstance();
                    }
                });
                return;
            }

            if (!Uri.TryCreate(line, UriKind.Absolute, out var uri) ||
                !string.Equals(uri.Scheme, "mcnexus", StringComparison.OrdinalIgnoreCase))
            {
                System.Diagnostics.Debug.WriteLine($"[DeepLink] Ignoring malformed URI: {line}");
                return;
            }

            Dispatcher.Invoke(() =>
            {
                if (MainWindow is MainWindow window)
                {
                    window.HandleDeepLink(uri);
                }
            });
        }

        private void TryRestartElevated()
        {
            try
            {
                var executablePath = Environment.ProcessPath;
                if (string.IsNullOrWhiteSpace(executablePath))
                {
                    throw new InvalidOperationException("The MCNexus executable path could not be resolved.");
                }

                var startInfo = new ProcessStartInfo
                {
                    FileName = executablePath,
                    UseShellExecute = true,
                    Verb = "runas",
                    WorkingDirectory = AppContext.BaseDirectory
                };
                startInfo.ArgumentList.Add(ElevatedRelaunchArgument);
                if (IsValidDeepLinkArgument(_pendingDeepLinkArgument))
                {
                    startInfo.ArgumentList.Add(_pendingDeepLinkArgument!);
                }

                var process = Process.Start(startInfo);

                if (process is null)
                {
                    throw new InvalidOperationException("Windows did not start the elevated MCNexus process.");
                }

                Shutdown();
            }
            catch (Win32Exception ex) when (ex.NativeErrorCode == ErrorCancelled)
            {
                ShowElevationRequiredWindow(
                    "Administrator permission was not granted.");
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Elevation Failed] {ex}");
                ShowElevationRequiredWindow(
                    "MCNexus could not restart with administrator permission.");
            }
        }

        private void ShowElevationRequiredWindow(string statusMessage)
        {
            if (_elevationRequiredWindow is null)
            {
                SetAppIconForTheme();
                _elevationRequiredWindow = new MainWindow(
                    isElevationRequiredMode: true,
                    elevationStatusMessage: statusMessage);
                _elevationRequiredWindow.ElevationTryAgainRequested += (_, _) => TryRestartElevated();
                _elevationRequiredWindow.ElevationCloseRequested += (_, _) => Shutdown();
                _elevationRequiredWindow.Closed += (_, _) =>
                {
                    _elevationRequiredWindow = null;
                    if (!Dispatcher.HasShutdownStarted)
                    {
                        Shutdown();
                    }
                };
                MainWindow = _elevationRequiredWindow;
                _elevationRequiredWindow.Show();
            }
            else
            {
                _elevationRequiredWindow.UpdateElevationStatus(statusMessage);
            }

            _elevationRequiredWindow.Activate();
        }

        private static bool IsRunningAsAdministrator()
        {
            try
            {
                using var identity = WindowsIdentity.GetCurrent();
                var principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"[Elevation Check Failed] {ex}");
                return false;
            }
        }

        private void SetAppIconForTheme()
        {
            var isDarkTheme = !IsLightThemeEnabled();
            var resourceKey = isDarkTheme ? "AppIconDark" : "AppIconLight";

            if (Resources.Contains(resourceKey) && Resources[resourceKey] is BitmapImage bitmap)
            {
                Resources["AppIcon"] = bitmap;

                foreach (Window window in Windows)
                {
                    window.Icon = bitmap;
                }

                ApplyNativeThemeIcons(resourceKey);
            }
        }

        internal void RefreshThemeIcon()
        {
            SetAppIconForTheme();
        }

        private void ApplyNativeThemeIcons(string resourceKey)
        {
            var iconPath = ResolveThemeIconPath(resourceKey);
            if (iconPath is null)
            {
                System.Diagnostics.Debug.WriteLine($"[Theme Icon] Native icon file was not found for {resourceKey}.");
                return;
            }

            System.Diagnostics.Debug.WriteLine($"[Theme Icon] Applying {resourceKey} from {iconPath}.");

            var newSmallIcon = LoadImage(IntPtr.Zero, iconPath, ImageIcon, 16, 16, LoadFromFile);
            var newLargeIcon = LoadImage(IntPtr.Zero, iconPath, ImageIcon, 32, 32, LoadFromFile);
            if (newSmallIcon == IntPtr.Zero || newLargeIcon == IntPtr.Zero)
            {
                if (newSmallIcon != IntPtr.Zero)
                {
                    DestroyIcon(newSmallIcon);
                }

                if (newLargeIcon != IntPtr.Zero)
                {
                    DestroyIcon(newLargeIcon);
                }

                System.Diagnostics.Debug.WriteLine($"[Theme Icon] Windows could not load {iconPath}.");
                return;
            }

            foreach (Window window in Windows)
            {
                var windowHandle = new WindowInteropHelper(window).Handle;
                if (windowHandle == IntPtr.Zero)
                {
                    continue;
                }

                SendMessage(windowHandle, WmSetIcon, new IntPtr(IconSmall), newSmallIcon);
                SendMessage(windowHandle, WmSetIcon, new IntPtr(IconBig), newLargeIcon);
            }

            ReleaseNativeThemeIcons();
            _smallThemeIconHandle = newSmallIcon;
            _largeThemeIconHandle = newLargeIcon;
        }

        private static string? ResolveThemeIconPath(string resourceKey)
        {
            var fileName = resourceKey == "AppIconLight"
                ? "AppIconLight.ico"
                : "AppIconDark.ico";
            var candidates = new[]
            {
                Path.Combine(AppContext.BaseDirectory, fileName),
                Path.Combine(AppContext.BaseDirectory, "Assets", fileName)
            };

            foreach (var candidate in candidates)
            {
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }

            return null;
        }

        private void ReleaseNativeThemeIcons()
        {
            if (_smallThemeIconHandle != IntPtr.Zero)
            {
                DestroyIcon(_smallThemeIconHandle);
                _smallThemeIconHandle = IntPtr.Zero;
            }

            if (_largeThemeIconHandle != IntPtr.Zero)
            {
                DestroyIcon(_largeThemeIconHandle);
                _largeThemeIconHandle = IntPtr.Zero;
            }
        }

        private void TrySubscribeToThemeChanges()
        {
            try
            {
                SystemEvents.UserPreferenceChanged += SystemEvents_UserPreferenceChanged;
                _isUserPreferenceChangedSubscribed = true;
            }
            catch (Exception ex) when (ex is InvalidOperationException or System.Runtime.InteropServices.ExternalException)
            {
                System.Diagnostics.Debug.WriteLine($"[Theme Change Monitoring Unavailable] {ex.Message}");
            }
        }

        private void SystemEvents_UserPreferenceChanged(object sender, UserPreferenceChangedEventArgs e)
        {
            if (e.Category is not (
                UserPreferenceCategory.Color or
                UserPreferenceCategory.General or
                UserPreferenceCategory.VisualStyle))
            {
                return;
            }

            _ = Dispatcher.InvokeAsync(() =>
            {
                SetAppIconForTheme();
                _trayIconService?.RefreshTheme(IsLightThemeEnabled());
            });
        }

        internal static bool IsLightThemeEnabled()
        {
            try
            {
                using var personalizeKey = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
                if (personalizeKey?.GetValue("AppsUseLightTheme") is int value)
                {
                    return value != 0;
                }
            }
            catch
            {
                // Ignore and use default dark theme.
            }

            return false;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern IntPtr LoadImage(
            IntPtr instance,
            string name,
            uint type,
            int desiredWidth,
            int desiredHeight,
            uint loadFlags);

        [DllImport("user32.dll")]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern IntPtr SendMessage(
            IntPtr windowHandle,
            int message,
            IntPtr wordParameter,
            IntPtr longParameter);

        [DllImport("user32.dll")]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DestroyIcon(IntPtr iconHandle);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.System32)]
        private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);

        private static bool IsValidDeepLinkArgument(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)
                || !value.StartsWith(DeepLinkArgumentPrefix, StringComparison.OrdinalIgnoreCase)
                || value.IndexOfAny(new[] { '"', '\r', '\n', '\0' }) >= 0)
            {
                return false;
            }

            return Uri.TryCreate(value, UriKind.Absolute, out var uri)
                && string.Equals(uri.Scheme, "mcnexus", StringComparison.OrdinalIgnoreCase);
        }
    }
}
