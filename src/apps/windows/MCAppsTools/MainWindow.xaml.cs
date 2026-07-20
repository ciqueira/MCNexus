using System;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace MCAppsTools
{
    public partial class MainWindow : Window
    {
        private readonly MainWindowViewModel _viewModel;
        private readonly bool _isElevationRequiredMode;

        public MainWindow()
            : this(isElevationRequiredMode: false, elevationStatusMessage: null)
        {
        }

        public MainWindow(bool isElevationRequiredMode, string? elevationStatusMessage)
        {
            InitializeComponent();
            _isElevationRequiredMode = isElevationRequiredMode;
            _viewModel = new MainWindowViewModel(MachineFingerprintService.Generate());
            DataContext = _viewModel;
            Loaded += MainWindow_Loaded;
            ContentRendered += MainWindow_ContentRendered;

            if (_isElevationRequiredMode)
            {
                ShowElevationOverlay(
                    elevationStatusMessage ?? "Administrator permission was not granted.");
            }
            else
            {
                _ = _viewModel.WarmBackendAsync();
            }
        }

        public event EventHandler? ElevationTryAgainRequested;
        public event EventHandler? ElevationCloseRequested;

        protected override void OnSourceInitialized(System.EventArgs e)
        {
            base.OnSourceInitialized(e);

            if (Application.Current is App app)
            {
                app.RefreshThemeIcon();
            }
        }

        private void MainWindow_Loaded(object sender, RoutedEventArgs e)
        {
            RefreshThemeIcon();
        }

        private void MainWindow_ContentRendered(object? sender, System.EventArgs e)
        {
            RefreshThemeIcon();
        }

        protected override void OnActivated(System.EventArgs e)
        {
            base.OnActivated(e);
            RefreshThemeIcon();
            if (!_isElevationRequiredMode)
            {
                _viewModel.OnAppActivated();
            }
        }

        protected override void OnClosed(EventArgs e)
        {
            _viewModel.Dispose();
            base.OnClosed(e);
        }

        private static void RefreshThemeIcon()
        {
            if (Application.Current is App app)
            {
                app.RefreshThemeIcon();
            }
        }

        private void LicenseCard_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button { Tag: PluginLicenseItem license })
            {
                _viewModel.SelectLicense(license);
            }
        }

        private void ToggleActivationPanel_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.IsShowingActivationPanel = !_viewModel.IsShowingActivationPanel;
            if (_viewModel.IsShowingActivationPanel)
            {
                LicenseKeyTextBox.Focus();
                ScrollTo(ActivationPanel);
            }
        }

        private async void ActivateButton_Click(object sender, RoutedEventArgs e)
        {
            await _viewModel.ActivateLicenseAsync(ScrollToStatusPanel);
        }

        private async void PrimaryLicenseAction_Click(object sender, RoutedEventArgs e)
        {
            await _viewModel.ExecutePrimaryActionAsync(ScrollToStatusPanel);
        }

        private async void LicenseAction_Click(object sender, RoutedEventArgs e)
        {
            if (sender is not Button { Tag: LicenseActionKind action })
            {
                return;
            }

            switch (action)
            {
                case LicenseActionKind.Update:
                case LicenseActionKind.RetryInstallation:
                    await _viewModel.ExecutePrimaryActionAsync(ScrollToStatusPanel);
                    break;
                case LicenseActionKind.Deactivate:
                    ConfirmDeactivate();
                    break;
                case LicenseActionKind.RemoveKey:
                    _viewModel.RemoveSelectedLicense();
                    break;
                case LicenseActionKind.RemovePlugin:
                    ConfirmRemovePlugin();
                    break;
                case LicenseActionKind.OnlineSupport:
                    OpenUrl(_viewModel.SupportUrl, "Could not open the support page.", "Online Support");
                    break;
            }
        }

        private void SecondaryLicenseAction_Click(object sender, RoutedEventArgs e)
        {
            if (_viewModel.SelectedLicense == null)
            {
                return;
            }

            if (_viewModel.SelectedLicense.LifecycleState == PluginLifecycleState.Deactivating ||
                _viewModel.SelectedLicense.IsRevoked)
            {
                _viewModel.RemoveSelectedLicense();
                return;
            }

            ConfirmDeactivate();
        }

        private void RemoveKey_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.RemoveSelectedLicense();
        }

        private void RemovePluginButton_Click(object sender, RoutedEventArgs e)
        {
            ConfirmRemovePlugin();
        }

        private void ConfirmDeactivate()
        {
            var result = MessageBox.Show(
                "This removes the license activation from this computer. Plugin files will stay installed.",
                "Deactivate license?",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);

            if (result == MessageBoxResult.Yes)
            {
                _viewModel.DeactivateSelectedLicense();
            }
        }

        private void ConfirmRemovePlugin()
        {
            var result = MessageBox.Show(
                "This removes the plugin files from this computer. Your license key will stay saved.",
                "Remove plugin?",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (result == MessageBoxResult.Yes)
            {
                _viewModel.RemovePluginFromSelectedLicense();
            }
        }

        private async void RetryInstallation_Click(object sender, RoutedEventArgs e)
        {
            await _viewModel.RetryInstallationAsync(ScrollToStatusPanel);
        }

        private void CancelInstallation_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.CancelInstallationError();
        }

        private void TogglePreviousVersions_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.TogglePreviousVersions();
        }

        private async void InstallPreviousVersion_Click(object sender, RoutedEventArgs e)
        {
            if (sender is Button { Tag: ReleaseVersionInfo version })
            {
                await _viewModel.InstallPreviousVersionAsync(version, ScrollToStatusPanel);
            }
        }

        private void RetrySync_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.RetrySync();
        }

        private void SupportOnline_Click(object sender, RoutedEventArgs e)
        {
            OpenUrl(_viewModel.SupportUrl, "Could not open the support page.", "Online Support");
        }

        private void AppUpdate_Click(object sender, RoutedEventArgs e)
        {
            if (!string.IsNullOrWhiteSpace(_viewModel.LatestAppDownloadUrl))
            {
                try
                {
                    System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = _viewModel.LatestAppDownloadUrl,
                        UseShellExecute = true
                    });
                }
                catch
                {
                    MessageBox.Show("Could not open the update download page.", "App Update", MessageBoxButton.OK, MessageBoxImage.Error);
                }
            }
            else
            {
                MessageBox.Show("No update download link is available.", "Update available", MessageBoxButton.OK, MessageBoxImage.Information);
            }
        }

        private void DismissAppUpdate_Click(object sender, RoutedEventArgs e)
        {
            _viewModel.DismissAppUpdate();
        }

        private async void CopyDiagnostics_Click(object sender, RoutedEventArgs e)
        {
            var payload = _viewModel.DiagnosticsPayload;
            if (string.IsNullOrWhiteSpace(payload))
            {
                MessageBox.Show("No diagnostics are available to copy.", "Diagnostics", MessageBoxButton.OK, MessageBoxImage.Information);
                return;
            }

            try
            {
                await SetClipboardTextAsync(payload);
                MessageBox.Show("Diagnostics copied to clipboard.", "Diagnostics", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            catch (Exception ex) when (ex is COMException or ExternalException or InvalidOperationException)
            {
                MessageBox.Show(
                    $"Could not copy diagnostics to the clipboard.\n\nTry again after closing any app that may be using the clipboard.\n\nDiagnostics:\n{payload}",
                    "Diagnostics",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }

        private static async Task SetClipboardTextAsync(string text)
        {
            Exception? lastError = null;

            for (var attempt = 0; attempt < 5; attempt++)
            {
                try
                {
                    Clipboard.SetDataObject(text, copy: true);
                    return;
                }
                catch (Exception ex) when (ex is COMException or ExternalException or InvalidOperationException)
                {
                    lastError = ex;
                    await Task.Delay(80 * (attempt + 1));
                }
            }

            throw new InvalidOperationException("The Windows clipboard is not available.", lastError);
        }

        private void MinimizeWindow_Click(object sender, RoutedEventArgs e)
        {
            WindowState = WindowState.Minimized;
        }

        private void CloseWindow_Click(object sender, RoutedEventArgs e)
        {
            Close();
        }

        public void UpdateElevationStatus(string statusMessage)
        {
            ShowElevationOverlay(statusMessage);
        }

        private void ShowElevationOverlay(string statusMessage)
        {
            ElevationStatusText.Text = statusMessage;
            ElevationOverlay.Visibility = Visibility.Visible;
        }

        private void ElevationTryAgain_Click(object sender, RoutedEventArgs e)
        {
            ElevationTryAgainRequested?.Invoke(this, EventArgs.Empty);
        }

        private void ElevationClose_Click(object sender, RoutedEventArgs e)
        {
            ElevationCloseRequested?.Invoke(this, EventArgs.Empty);
        }

        private void ScrollToStatusPanel()
        {
            Dispatcher.InvokeAsync(() => ScrollTo(StatusPanel));
        }

        private void ScrollTo(FrameworkElement element)
        {
            element.BringIntoView();
        }

        private static void OpenUrl(string? url, string errorMessage, string title)
        {
            if (string.IsNullOrWhiteSpace(url))
            {
                MessageBox.Show(errorMessage, title, MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            try
            {
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = url,
                    UseShellExecute = true
                });
            }
            catch
            {
                MessageBox.Show(errorMessage, title, MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
