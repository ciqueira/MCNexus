using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Principal;
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

        private bool _isUserPreferenceChangedSubscribed;
        private IntPtr _smallThemeIconHandle;
        private IntPtr _largeThemeIconHandle;
        private MainWindow? _elevationRequiredWindow;

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

            if (IsRunningAsAdministrator())
            {
                OpenMainWindow();
                return;
            }

            if (e.Args.Contains(ElevatedRelaunchArgument, StringComparer.OrdinalIgnoreCase))
            {
                ShowElevationRequiredWindow(
                    "MCNexus could not restart with administrator permission.");
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

        private void TryRestartElevated()
        {
            try
            {
                var executablePath = Environment.ProcessPath;
                if (string.IsNullOrWhiteSpace(executablePath))
                {
                    throw new InvalidOperationException("The MCNexus executable path could not be resolved.");
                }

                var process = Process.Start(new ProcessStartInfo
                {
                    FileName = executablePath,
                    Arguments = ElevatedRelaunchArgument,
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
