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
            var deepLinkArgument = e.Args.FirstOrDefault(
                a => a.StartsWith(DeepLinkArgumentPrefix, StringComparison.OrdinalIgnoreCase));
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

            var window = new MainWindow();
            MainWindow = window;
            ShutdownMode = ShutdownMode.OnMainWindowClose;
            window.Show();
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
            // This instance runs elevated, so objects it creates are labelled
            // High integrity by default — which silently blocks writes from
            // the medium-integrity process a plain shell URL activation
            // actually runs as (Mandatory Integrity Control, not the DACL
            // below). The DACL alone is necessary but not sufficient; the
            // explicit Medium mandatory label with no restriction removes
            // that ceiling and is the part that actually fixes delivery.
            var pipeSecurity = new PipeSecurity();
            pipeSecurity.AddAccessRule(new PipeAccessRule(
                new SecurityIdentifier(WellKnownSidType.AuthenticatedUserSid, null),
                PipeAccessRights.Write | PipeAccessRights.Synchronize,
                AccessControlType.Allow));
            pipeSecurity.AddAccessRule(new PipeAccessRule(
                new SecurityIdentifier(WellKnownSidType.BuiltinAdministratorsSid, null),
                PipeAccessRights.FullControl,
                AccessControlType.Allow));
            pipeSecurity.SetSecurityDescriptorSddlForm("S:(ML;;;;;ME)", AccessControlSections.Audit);

            while (!cancellationToken.IsCancellationRequested)
            {
                try
                {
                    using var server = NamedPipeServerStreamAcl.Create(
                        DeepLinkPipeName,
                        PipeDirection.In,
                        maxNumberOfServerInstances: 1,
                        PipeTransmissionMode.Byte,
                        PipeOptions.Asynchronous,
                        inBufferSize: 0,
                        outBufferSize: 0,
                        pipeSecurity);

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

                // Quoted so a deep link's own '&'/query string cannot be
                // reinterpreted as a second shell argument.
                var arguments = _pendingDeepLinkArgument is null
                    ? ElevatedRelaunchArgument
                    : $"{ElevatedRelaunchArgument} \"{_pendingDeepLinkArgument}\"";

                var process = Process.Start(new ProcessStartInfo
                {
                    FileName = executablePath,
                    Arguments = arguments,
                    UseShellExecute = true,
                    Verb = "runas",
                    WorkingDirectory = AppContext.BaseDirectory
                });

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

            _ = Dispatcher.InvokeAsync(SetAppIconForTheme);
        }

        private static bool IsLightThemeEnabled()
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
        private static extern IntPtr LoadImage(
            IntPtr instance,
            string name,
            uint type,
            int desiredWidth,
            int desiredHeight,
            uint loadFlags);

        [DllImport("user32.dll")]
        private static extern IntPtr SendMessage(
            IntPtr windowHandle,
            int message,
            IntPtr wordParameter,
            IntPtr longParameter);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DestroyIcon(IntPtr iconHandle);

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern int SetCurrentProcessExplicitAppUserModelID(string appId);
    }
}
