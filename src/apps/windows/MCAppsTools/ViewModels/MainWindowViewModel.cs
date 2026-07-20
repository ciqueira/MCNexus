using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Net;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Media;
using System.Windows.Threading;

namespace MCAppsTools
{
    public sealed class MainWindowViewModel : NotifyObject, IDisposable
    {
        private const string ValidKeyPattern = "^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{8}$";
        private const string DefaultPublicWebsiteUrl = "https://github.com/ciqueira/MCNexus/issues";
        private const int MaxSyncBatchItems = 10;
        private static readonly Regex KeyRegex = new(ValidKeyPattern, RegexOptions.Compiled);

        private PluginLicenseItem? _selectedLicense;
        private bool _isShowingActivationPanel;
        private string _licenseKeyInput = string.Empty;
        private string? _activationErrorMessage;
        private bool _isBusy;
        private LicenseSyncState _syncState = LicenseSyncState.Idle;
        private Visibility _appUpdateBannerVisibility = Visibility.Collapsed;
        private string _syncNoticeMessage = string.Empty;
        private string _supportCodeText = string.Empty;
        private bool _hasSyncNotice;
        private readonly LicenseStorageService _storageService;
        private readonly AppBackendService _backendService;
        private readonly InstallService _installService = new();
        private readonly LexService _lexService = new();
        private System.Threading.Timer? _sdkPollTimer;
        private System.Threading.Timer? _heartbeatTimer;
        private string? _dismissedAppUpdateVersion;
        private string? _latestAppVersion;
        private readonly DispatcherTimer _uiTimer;
        private bool _isSdkPollRunning;
        private bool _isSyncRunning;
        private bool _isInstallationInteractionLocked;
        private DateTime? _lastSuccessfulSyncDate;
        private readonly Dictionary<Guid, InstallationRetryContext> _installationRetryContexts = new();

        public MainWindowViewModel(string machineFingerprint)
            : this(machineFingerprint, new AppBackendService(machineFingerprint))
        {
        }

        public MainWindowViewModel(string machineFingerprint, AppBackendService backendService)
        {
            MachineFingerprint = machineFingerprint;
            _backendService = backendService;
            _storageService = new LicenseStorageService(machineFingerprint);
            Licenses = new ObservableCollection<PluginLicenseItem>();

            _uiTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
            _uiTimer.Tick += (s, e) =>
            {
                OnPropertyChanged(nameof(RetrySyncText));
                OnPropertyChanged(nameof(CanRetrySync));
            };
            _uiTimer.Start();

            var storedLicenses = _storageService.Load();
            IEnumerable<PluginLicenseItem> initialLicenses = storedLicenses is not null
                ? storedLicenses
                : Array.Empty<PluginLicenseItem>();
            foreach (var license in initialLicenses)
            {
                NormalizeInterruptedInstallation(license);
                Licenses.Add(license);
            }

            if (Licenses.Count > 0)
            {
                SelectLicense(Licenses[0]);
            }
            else
            {
                IsShowingActivationPanel = true;
            }

            _syncNoticeMessage = "Could not refresh latest status. Saved local data is still available.";
            SaveLicenses();
        }

        public ObservableCollection<PluginLicenseItem> Licenses { get; }
        public string MachineFingerprint { get; }

        public PluginLicenseItem? SelectedLicense
        {
            get => _selectedLicense;
            set
            {
                if (SetProperty(ref _selectedLicense, value))
                {
                    RefreshCardSelection();
                    OnPropertyChanged(nameof(SelectedLicenseVisibility));
                }
            }
        }

        public string LicenseKeyInput
        {
            get => _licenseKeyInput;
            set
            {
                if (SetProperty(ref _licenseKeyInput, value))
                {
                    ActivationErrorMessage = null;
                    OnPropertyChanged(nameof(CanActivate));
                    OnPropertyChanged(nameof(LicenseKeyPlaceholderVisibility));
                }
            }
        }

        public bool IsShowingActivationPanel
        {
            get => _isShowingActivationPanel;
            set
            {
                if (SetProperty(ref _isShowingActivationPanel, value))
                {
                    OnPropertyChanged(nameof(ActivationPanelTitle));
                    OnPropertyChanged(nameof(ActivationFormVisibility));
                }
            }
        }

        public string ActivationPanelTitle => IsShowingActivationPanel ? "New license activation" : "Activate another license";
        public Visibility ActivationFormVisibility => IsShowingActivationPanel ? Visibility.Visible : Visibility.Collapsed;
        public Visibility LicenseKeyPlaceholderVisibility => string.IsNullOrWhiteSpace(LicenseKeyInput) ? Visibility.Visible : Visibility.Collapsed;

        public string? ActivationErrorMessage
        {
            get => _activationErrorMessage;
            set
            {
                if (SetProperty(ref _activationErrorMessage, value))
                {
                    OnPropertyChanged(nameof(ActivationErrorVisibility));
                }
            }
        }

        public Visibility ActivationErrorVisibility => string.IsNullOrWhiteSpace(ActivationErrorMessage) ? Visibility.Collapsed : Visibility.Visible;

        public bool IsBusy
        {
            get => _isBusy;
            set
            {
                if (SetProperty(ref _isBusy, value))
                {
                    OnPropertyChanged(nameof(CanInteract));
                    OnPropertyChanged(nameof(CanActivate));
                    OnPropertyChanged(nameof(CanRetrySync));
                }
            }
        }

        public bool CanInteract => !IsBusy && !_isInstallationInteractionLocked;
        public bool HasMachineFingerprint => !string.IsNullOrWhiteSpace(MachineFingerprint);
        public bool CanActivate => CanInteract && HasMachineFingerprint && !string.IsNullOrWhiteSpace(LicenseKeyInput);

        public Visibility LicenseListVisibility => Licenses.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
        public Visibility EmptyLicensesVisibility => Licenses.Count == 0 ? Visibility.Visible : Visibility.Collapsed;
        public Visibility SelectedLicenseVisibility => SelectedLicense == null ? Visibility.Collapsed : Visibility.Visible;

        public LicenseSyncState SyncState
        {
            get => _syncState;
            set
            {
                if (SetProperty(ref _syncState, value))
                {
                    OnPropertyChanged(nameof(SyncMessage));
                    OnPropertyChanged(nameof(SyncIcon));
                    OnPropertyChanged(nameof(SyncBrush));
                    OnPropertyChanged(nameof(IsSyncing));
                }
            }
        }

        public string SyncMessage => SyncState switch
        {
            LicenseSyncState.Syncing => "Syncing latest status...",
            LicenseSyncState.Synced => "Status updated",
            LicenseSyncState.Failed => "Could not refresh latest status",
            _ => "Using saved data"
        };

        public string SyncIcon => SyncState switch
        {
            LicenseSyncState.Syncing => "\uE895",
            LicenseSyncState.Synced => "\uE930",
            LicenseSyncState.Failed => "\uE7BA",
            _ => "\uE823"
        };

        public bool IsSyncing => SyncState == LicenseSyncState.Syncing;

        public Brush SyncBrush => SyncState switch
        {
            LicenseSyncState.Syncing => Brushes.StatusInfo,
            LicenseSyncState.Synced => Brushes.StatusActive,
            LicenseSyncState.Failed => Brushes.StatusError,
            _ => Brushes.TextSecondary
        };

        public Visibility SyncNoticeVisibility => _hasSyncNotice ? Visibility.Visible : Visibility.Collapsed;
        public string LastUpdatedText => _lastSuccessfulSyncDate.HasValue
            ? $"Last updated: {_lastSuccessfulSyncDate.Value:yyyy-MM-dd HH:mm:ss}"
            : "Last updated: saved data";
        public string RetrySyncText
        {
            get
            {
                var rateLimit = _backendService.RateLimitedUntil;
                if (rateLimit.HasValue && rateLimit.Value > DateTimeOffset.UtcNow)
                {
                    var remaining = (int)(rateLimit.Value - DateTimeOffset.UtcNow).TotalSeconds;
                    return $"Retry in {remaining}s";
                }
                return "Retry";
            }
        }

        public bool CanRetrySync
        {
            get
            {
                var rateLimit = _backendService.RateLimitedUntil;
                var notRateLimited = !rateLimit.HasValue || rateLimit.Value <= DateTimeOffset.UtcNow;
                return CanInteract && notRateLimited;
            }
        }
        public string SyncNoticeMessage => _syncNoticeMessage;
        public Visibility SupportCodeVisibility => string.IsNullOrWhiteSpace(SupportCodeText) ? Visibility.Collapsed : Visibility.Visible;

        public string SupportCodeText
        {
            get => _supportCodeText;
            set
            {
                if (SetProperty(ref _supportCodeText, value))
                {
                    OnPropertyChanged(nameof(SupportCodeVisibility));
                    OnPropertyChanged(nameof(DiagnosticsPayload));
                }
            }
        }

        public Visibility AppUpdateBannerVisibility
        {
            get => _appUpdateBannerVisibility;
            set => SetProperty(ref _appUpdateBannerVisibility, value);
        }

        private string _appUpdateVersionText = "Version 1.1.0 is ready";
        private string? _latestAppDownloadUrl;

        public string AppUpdateVersionText
        {
            get => _appUpdateVersionText;
            set => SetProperty(ref _appUpdateVersionText, value);
        }

        public string? LatestAppDownloadUrl
        {
            get => _latestAppDownloadUrl;
            set => SetProperty(ref _latestAppDownloadUrl, value);
        }

        public string SupportUrl => DefaultPublicWebsiteUrl;

        private static string CurrentTimestamp() => DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);

        private static void MarkLicenseRevoked(PluginLicenseItem license, string? feedbackMessage = null)
        {
            license.IsRevoked = true;
            license.AvailableVersion = null;
            license.AvailableReleaseId = null;
            license.LifecycleState = PluginLifecycleState.Deactivating;
            if (string.IsNullOrWhiteSpace(license.DeactivationDate))
            {
                license.DeactivationDate = CurrentTimestamp();
            }
            license.FeedbackMessage = string.IsNullOrWhiteSpace(feedbackMessage)
                ? "This key is no longer valid."
                : feedbackMessage;
            license.FeedbackBrush = Brushes.StatusError;
        }

        public string FingerprintText => HasMachineFingerprint ? $"Fingerprint ID {MachineFingerprint}" : "Fingerprint ID unavailable";
        public string AppClientVersionText => $"App Client Version {AppBackendConfiguration.AppVersion}";

        public string DiagnosticsPayload =>
            $"{FingerprintText}\nApp Client Version {AppBackendConfiguration.AppVersion}\nBackend Environment {AppBackendConfiguration.Environment.Name}";

        public async Task WarmBackendAsync()
        {
            await InitializeAsync();
        }

        public async Task InitializeAsync()
        {
            try
            {
                _ = await _backendService.CheckHealthAsync();
            }
            catch
            {
                // Health check is only a backend wake-up ping. The mock UI must keep working offline.
            }

            _ = CheckForAppUpdatesAsync();
            _ = SyncAllLicensesAsync();
            StartBackgroundTimers();
        }

        private async Task CheckForAppUpdatesAsync()
        {
            try
            {
                var response = await _backendService.FetchLatestAppAsync("windows");
                if (response != null && !string.IsNullOrWhiteSpace(response.Version))
                {
                    _latestAppVersion = response.Version;
                    if (_dismissedAppUpdateVersion == response.Version)
                    {
                        AppUpdateBannerVisibility = Visibility.Collapsed;
                        return;
                    }

                    var currentVersion = AppBackendConfiguration.AppVersion;
                    if (VersionSortKeyComparer.Instance.Compare(response.Version, currentVersion) > 0)
                    {
                        AppUpdateVersionText = $"Version {response.Version} is ready";
                        LatestAppDownloadUrl = response.DownloadUrl;
                        AppUpdateBannerVisibility = Visibility.Visible;
                    }
                    else
                    {
                        AppUpdateBannerVisibility = Visibility.Collapsed;
                    }
                }
            }
            catch
            {
                // Ignora falhas/400 silenciosamente mantendo o banner oculto
                AppUpdateBannerVisibility = Visibility.Collapsed;
            }
        }

        public void DismissAppUpdate()
        {
            _dismissedAppUpdateVersion = _latestAppVersion;
            AppUpdateBannerVisibility = Visibility.Collapsed;
        }

        private void StartBackgroundTimers()
        {
            _sdkPollTimer = new System.Threading.Timer(async _ =>
            {
                await RunOnDispatcherAsync(async () =>
                {
                    await PollSDKLicensesAsync();
                });
            }, null, TimeSpan.Zero, TimeSpan.FromSeconds(120));

            _heartbeatTimer = new System.Threading.Timer(async _ =>
            {
                await RunOnDispatcherAsync(async () =>
                {
                    if (IsBusy || Licenses.Any(l => l.LifecycleState == PluginLifecycleState.Activating))
                    {
                        return;
                    }
                    await SyncAllLicensesAsync();
                    await CheckForAppUpdatesAsync();
                });
            }, null, TimeSpan.FromSeconds(900), TimeSpan.FromSeconds(900));
        }

        public void OnAppActivated()
        {
            if (IsBusy || Licenses.Any(l => l.LifecycleState == PluginLifecycleState.Activating))
            {
                return;
            }
            _ = RefreshLicensesFromSdkSilentlyAsync();
        }

        private async Task RefreshLicensesFromSdkSilentlyAsync()
        {
            await PollSDKLicensesAsync();
        }

        private async Task PollSDKLicensesAsync()
        {
            if (_isSdkPollRunning || IsBusy || Licenses.Any(l => l.LifecycleState == PluginLifecycleState.Activating))
            {
                return;
            }

            _isSdkPollRunning = true;
            var changed = false;
            var needsBackendSync = false;
            try
            {
                foreach (var l in Licenses)
                {
                    if (l.IsCredentialMissing || l.SkipLocalActivation || l.LifecycleState == PluginLifecycleState.Activating || l.LifecycleState == PluginLifecycleState.Deactivating)
                    {
                        if (l.SkipLocalActivation && !l.IsRevoked && l.LifecycleState != PluginLifecycleState.Deactivating)
                        {
                            needsBackendSync = true; // Force cloud sync to validate beta/backend-only licenses.
                        }
                        continue;
                    }

                    if (!_storageService.KeyFileExists(l.Id))
                    {
                        l.IsCredentialMissing = true;
                        l.LifecycleState = PluginLifecycleState.Deactivating;
                        l.FeedbackMessage = "Corrupted license";
                        l.FeedbackBrush = Brushes.StatusError;
                        changed = true;
                        continue;
                    }

                    var sdkStatus = _lexService.SyncStatus(l.ProductId, l.ProductData);
                    switch (sdkStatus)
                    {
                        case SdkLicenseStatus.Active:
                            l.IsRevoked = false;
                            if (!l.InstallationFailed)
                            {
                                l.ClearWarningOrErrorFeedback();
                            }
                            if (l.LifecycleState == PluginLifecycleState.Suspended)
                            {
                                l.LifecycleState = string.IsNullOrWhiteSpace(l.AvailableVersion)
                                    ? PluginLifecycleState.Active
                                    : PluginLifecycleState.UpdateAvailable;
                                l.FeedbackMessage = "Status updated";
                                l.FeedbackBrush = Brushes.StatusActive;
                                changed = true;
                            }
                            break;
                        case SdkLicenseStatus.Suspended:
                            if (l.LifecycleState != PluginLifecycleState.Suspended)
                            {
                                l.LifecycleState = PluginLifecycleState.Suspended;
                                l.FeedbackMessage = "Suspended key";
                                l.FeedbackBrush = Brushes.StatusWarning;
                                changed = true;
                            }
                            break;
                        case SdkLicenseStatus.Revoked:
                            MarkLicenseRevoked(l);
                            changed = true;
                            break;
                        case SdkLicenseStatus.Expired:
                            l.AvailableVersion = null;
                            l.AvailableReleaseId = null;
                            l.LifecycleState = PluginLifecycleState.Deactivating;
                            l.FeedbackMessage = "This license is not available for activation.";
                            l.FeedbackBrush = Brushes.StatusError;
                            changed = true;
                            break;
                        case SdkLicenseStatus.NotActivated:
                            l.LifecycleState = PluginLifecycleState.Deactivating;
                            l.FeedbackMessage = "License verification failed on this machine.";
                            l.FeedbackBrush = Brushes.StatusError;
                            changed = true;
                            break;
                    }
                }

                if (changed)
                {
                    SaveLicenses();
                }

                if (changed || needsBackendSync)
                {
                    await SyncAllLicensesAsync();
                }
            }
            finally
            {
                _isSdkPollRunning = false;
            }
        }

        private static async Task RunOnDispatcherAsync(Func<Task> action)
        {
            if (Application.Current?.Dispatcher is { } dispatcher)
            {
                if (dispatcher.CheckAccess())
                {
                    await action();
                }
                else
                {
                    await dispatcher.InvokeAsync(async () => await action());
                }
            }
            else
            {
                await action();
            }
        }

        public void Dispose()
        {
            _uiTimer?.Stop();
            _sdkPollTimer?.Dispose();
            _heartbeatTimer?.Dispose();
        }

        public void SelectLicense(PluginLicenseItem license)
        {
            if (IsBusy)
            {
                return;
            }

            if (!license.InstallationFailed &&
                license.LifecycleState is PluginLifecycleState.Active or PluginLifecycleState.UpdateAvailable)
            {
                license.ClearWarningOrErrorFeedback();
            }

            SelectedLicense = license;
        }

        public async Task ActivateLicenseAsync(Action scrollToStatus)
        {
            var normalizedKey = LicenseKeyInput.Trim().ToUpperInvariant();
            if (!HasMachineFingerprint)
            {
                ActivationErrorMessage = "Machine fingerprint unavailable. Activation requires a real Windows hardware UUID.";
                return;
            }

            if (!KeyRegex.IsMatch(normalizedKey))
            {
                ActivationErrorMessage = "Invalid key format. Expected XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXXXX.";
                return;
            }

            var keyHash = LicenseKeyIdentity.Hash(normalizedKey);
            foreach (var license in Licenses)
            {
                if (string.Equals(license.LicenseKeyHash, keyHash, StringComparison.OrdinalIgnoreCase))
                {
                    ActivationErrorMessage = "This license key is already active in the manager.";
                    return;
                }
            }

            // Instantly transition UI to Activating status checklist panel
            var newLicense = PluginLicenseItem.Create(
                "Validating license...",
                "",
                LicenseEdition.Full,
                PluginLifecycleState.Activating,
                normalizedKey,
                null,
                null,
                null,
                null,
                DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture),
                DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture),
                "--",
                Array.Empty<ReleaseVersionInfo>(),
                false);

            Licenses.Insert(0, newLicense);
            RefreshCollectionState();
            SelectedLicense = newLicense;
            IsShowingActivationPanel = false;
            LicenseKeyInput = string.Empty;
            ActivationErrorMessage = null;
            SupportCodeText = string.Empty;
            scrollToStatus();

            _installationRetryContexts[newLicense.Id] = InstallationRetryContext.CaptureNewActivation();
            var result = await RunWorkflowAsync(newLicense, null, null, activateOnMachine: true);
            if (result.Success)
            {
                CommitPendingInstall(newLicense.Id);
                _installationRetryContexts.Remove(newLicense.Id);
                await Task.Delay(1500);
                newLicense.InstalledVersion = result.TargetVersion;
                newLicense.InstalledReleaseId = result.TargetReleaseId;
                newLicense.InstallationTargetVersion = null;

                if (!string.IsNullOrWhiteSpace(result.LatestVersion) && 
                    !string.Equals(result.TargetVersion, result.LatestVersion, StringComparison.OrdinalIgnoreCase))
                {
                    newLicense.AvailableVersion = result.LatestVersion;
                    newLicense.AvailableReleaseId = result.LatestReleaseId;
                    newLicense.LifecycleState = PluginLifecycleState.UpdateAvailable;
                }
                else
                {
                    newLicense.AvailableVersion = null;
                    newLicense.AvailableReleaseId = null;
                    newLicense.LifecycleState = PluginLifecycleState.Active;
                }

                newLicense.FeedbackMessage = result.SuccessMessage ?? "Installation completed successfully";
                newLicense.FeedbackBrush = Brushes.StatusActive;
                SetInstallationInteractionLock(false);
                SaveLicenses();
            }
        }

        private async Task<BackendActivationValidation> ValidateInstallationWithBackendAsync(string normalizedKey, bool activateOnMachine)
        {
            var response = await _backendService.ValidateInstallationAsync(new ValidateInstallationRequestDto
            {
                Key = normalizedKey,
                MachineFingerprint = MachineFingerprint,
                ActivateOnMachine = activateOnMachine
            });

            if (!string.IsNullOrWhiteSpace(response.SessionToken) && response.ExpiresIn.GetValueOrDefault() > 0)
            {
                _backendService.SessionTokens.Store(response.SessionToken, response.ExpiresIn.Value, normalizedKey);
            }

            var releases = response.Releases
                .Where(release => string.Equals(release.Platform, "windows", StringComparison.OrdinalIgnoreCase))
                .Select(release => new ReleaseVersionInfo(release.Version, string.IsNullOrWhiteSpace(release.Channel) ? "stable" : release.Channel!, release.Id))
                .Where(release => !string.IsNullOrWhiteSpace(release.Version))
                .GroupBy(release => release.Version, StringComparer.OrdinalIgnoreCase)
                .Select(group => group.First())
                .OrderByDescending(release => release.Version, VersionSortKeyComparer.Instance)
                .ToList();

            if (releases.Count == 0)
            {
                throw new AppBackendException(
                    AppBackendErrorKind.Http,
                    "No Windows release is available for this license.",
                    statusCode: HttpStatusCode.NotFound,
                    payload: new AppBackendErrorDto
                    {
                        Code = "release_not_found",
                        Message = "No Windows release is available for this license."
                    });
            }

            var latest = releases[0];
            var previousVersions = releases
                .Skip(1)
                .Where(r => !string.Equals(r.Version, latest.Version, StringComparison.OrdinalIgnoreCase))
                .Take(5)
                .ToArray();
            var pluginName = string.IsNullOrWhiteSpace(response.Product.Name) ? "MC Plugin" : response.Product.Name;

            return new BackendActivationValidation(
                pluginName,
                response.Product.ProductId,
                EditionFromBackend(response.Edition),
                latest.Version,
                latest.ReleaseId,
                response.ActivationUsage,
                previousVersions,
                response.Message?.Message,
                response.SkipLocalActivation.GetValueOrDefault(false),
                response.Product.ProductData,
                response.Product.PurchaseUrl);
        }

        public async Task ExecutePrimaryActionAsync(Action scrollToStatus)
        {
            if (SelectedLicense == null)
            {
                return;
            }

            if (SelectedLicense.LifecycleState == PluginLifecycleState.UpdateAvailable)
            {
                await InstallUpdateAsync(SelectedLicense, scrollToStatus);
                return;
            }

            if (SelectedLicense.LifecycleState == PluginLifecycleState.Deactivating && !SelectedLicense.IsCorrupted)
            {
                await RetryInstallationAsync(scrollToStatus);
                return;
            }

            if (SelectedLicense.HasSavedLicense &&
                !SelectedLicense.HasInstalledPlugin &&
                !SelectedLicense.IsCorrupted &&
                !SelectedLicense.IsRevoked &&
                SelectedLicense.LifecycleState != PluginLifecycleState.Suspended)
            {
                await RetryInstallationAsync(scrollToStatus);
            }
        }

        public async Task RetryInstallationAsync(Action scrollToStatus)
        {
            if (SelectedLicense == null || SelectedLicense.IsCorrupted)
            {
                return;
            }

            if (_installationRetryContexts.TryGetValue(SelectedLicense.Id, out var retryContext))
            {
                if (retryContext.RemoveLicenseOnCancel)
                {
                    await RunNewActivationRetryAsync(SelectedLicense, scrollToStatus, retryContext);
                    return;
                }

                await InstallUpdateAsync(
                    SelectedLicense,
                    scrollToStatus,
                    retryContext.TargetVersion,
                    retryContext.IsPreviousVersion,
                    retryContext.TargetReleaseId,
                    keepExistingRetryContext: true);
                return;
            }

            var targetVersion = SelectedLicense.LifecycleState == PluginLifecycleState.Deactivating ? null : SelectedLicense.AvailableVersion ?? SelectedLicense.InstalledVersion;
            await InstallUpdateAsync(SelectedLicense, scrollToStatus, targetVersion);
        }

        public async Task InstallPreviousVersionAsync(ReleaseVersionInfo version, Action scrollToStatus)
        {
            if (SelectedLicense == null)
            {
                return;
            }

            // Mirrors macOS: close dropdown immediately before starting workflow
            SelectedLicense.IsShowingPreviousVersions = false;

            await InstallUpdateAsync(SelectedLicense, scrollToStatus, version.Version, isPreviousVersion: true);
        }

        private async Task InstallUpdateAsync(
            PluginLicenseItem license,
            Action scrollToStatus,
            string? targetVersion = null,
            bool isPreviousVersion = false,
            string? targetReleaseIdOverride = null,
            bool keepExistingRetryContext = false)
        {
            string? targetReleaseId = targetReleaseIdOverride;
            if (!string.IsNullOrEmpty(targetVersion))
            {
                if (!string.IsNullOrWhiteSpace(targetReleaseIdOverride))
                {
                    targetReleaseId = targetReleaseIdOverride;
                }
                else if (targetVersion == license.AvailableVersion && !string.IsNullOrWhiteSpace(license.AvailableReleaseId))
                {
                    targetReleaseId = license.AvailableReleaseId;
                }
                else if (targetVersion == license.InstalledVersion && !string.IsNullOrWhiteSpace(license.InstalledReleaseId))
                {
                    targetReleaseId = license.InstalledReleaseId;
                }
                else
                {
                    var matchedPrev = license.PreviousVersions.FirstOrDefault(v => v.Version == targetVersion);
                    if (matchedPrev != null && !string.IsNullOrWhiteSpace(matchedPrev.ReleaseId))
                    {
                        targetReleaseId = matchedPrev.ReleaseId;
                    }
                }
            }

            var previous = license.InstalledVersion;
            var previousReleaseId = license.InstalledReleaseId;
            var displayTargetVersion = targetVersion ?? license.AvailableVersion;
            var activateOnMachine = license.LifecycleState == PluginLifecycleState.Deactivating;
            if (!keepExistingRetryContext || !_installationRetryContexts.TryGetValue(license.Id, out var retryContext))
            {
                retryContext = InstallationRetryContext.Capture(
                    license,
                    targetVersion,
                    targetReleaseId,
                    isPreviousVersion,
                    activateOnMachine);
                _installationRetryContexts[license.Id] = retryContext;
            }
            else
            {
                if (!RollbackPendingInstall(license, restoreStateForRetry: true))
                {
                    return;
                }

                activateOnMachine = retryContext.ActivateOnMachine;
            }

            // Mirrors macOS: close dropdown immediately
            license.IsShowingPreviousVersions = false;
            license.InstallationTargetVersion = displayTargetVersion;
            scrollToStatus();

            var result = await RunWorkflowAsync(license, targetReleaseId, targetVersion, activateOnMachine);
            if (!result.Success)
            {
                return;
            }

            CommitPendingInstall(license.Id);
            _installationRetryContexts.Remove(license.Id);

            if (!string.IsNullOrWhiteSpace(previous) && previous != result.TargetVersion)
            {
                license.PreviousVersions.Insert(0, new ReleaseVersionInfo(previous, "stable", previousReleaseId ?? string.Empty));
            }

            await Task.Delay(1500);
            license.InstalledVersion = result.TargetVersion;
            license.InstalledReleaseId = result.TargetReleaseId;
            license.InstallationTargetVersion = null;
            license.IsShowingPreviousVersions = false;
            license.PluginUpdateDate = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
            license.DeactivationDate = null;
            license.FeedbackMessage = result.SuccessMessage ?? "Installation completed successfully";
            license.FeedbackBrush = Brushes.StatusActive;

            if (isPreviousVersion && !string.IsNullOrWhiteSpace(result.LatestVersion) && 
                !string.Equals(result.TargetVersion, result.LatestVersion, StringComparison.OrdinalIgnoreCase))
            {
                // Mirrors macOS installPreviousVersion: if the installed version is not the latest known,
                // expose the latest as AvailableVersion and switch to UpdateAvailable state.
                license.AvailableVersion = result.LatestVersion;
                license.AvailableReleaseId = result.LatestReleaseId;
                license.LifecycleState = PluginLifecycleState.UpdateAvailable;
            }
            else
            {
                license.AvailableVersion = null;
                license.AvailableReleaseId = null;
                license.LifecycleState = PluginLifecycleState.Active;
            }

            SetInstallationInteractionLock(false);
            SaveLicenses();
        }

        private async Task RunNewActivationRetryAsync(
            PluginLicenseItem license,
            Action scrollToStatus,
            InstallationRetryContext retryContext)
        {
            if (!RollbackPendingInstall(license, restoreStateForRetry: true))
            {
                return;
            }

            license.InstallationTargetVersion = retryContext.TargetVersion ?? license.InstallationTargetVersion;
            scrollToStatus();
            var result = await RunWorkflowAsync(
                license,
                retryContext.TargetReleaseId,
                retryContext.TargetVersion,
                activateOnMachine: true);
            if (!result.Success)
            {
                return;
            }

            CommitPendingInstall(license.Id);
            _installationRetryContexts.Remove(license.Id);

            await Task.Delay(1500);
            license.InstalledVersion = result.TargetVersion;
            license.InstalledReleaseId = result.TargetReleaseId;
            license.InstallationTargetVersion = null;

            if (!string.IsNullOrWhiteSpace(result.LatestVersion) &&
                !string.Equals(result.TargetVersion, result.LatestVersion, StringComparison.OrdinalIgnoreCase))
            {
                license.AvailableVersion = result.LatestVersion;
                license.AvailableReleaseId = result.LatestReleaseId;
                license.LifecycleState = PluginLifecycleState.UpdateAvailable;
            }
            else
            {
                license.AvailableVersion = null;
                license.AvailableReleaseId = null;
                license.LifecycleState = PluginLifecycleState.Active;
            }

            license.FeedbackMessage = result.SuccessMessage ?? "Installation completed successfully";
            license.FeedbackBrush = Brushes.StatusActive;
            SetInstallationInteractionLock(false);
            SaveLicenses();
        }



        private async Task<(bool Success, string? TargetReleaseId, string? TargetVersion, string? LatestVersion, string? LatestReleaseId, string? SuccessMessage)> RunWorkflowAsync(
            PluginLicenseItem license,
            string? releaseId,
            string? targetVersion,
            bool activateOnMachine)
        {
            SetInstallationInteractionLock(true);
            IsBusy = true;
            license.BeginWorkflow();
            license.LifecycleState = PluginLifecycleState.Activating;
            string? downloadedZipPath = null;
            string? resolvedReleaseId = releaseId;
            string? resolvedTargetVersion = targetVersion;
            string? latestVersion = null;
            string? latestReleaseId = null;
            string? successMessage = null;

            for (var i = 0; i < license.InstallationSteps.Count; i++)
            {
                var step = license.InstallationSteps[i];
                step.Status = InstallationStepStatus.Running;

                try
                {
                    if (step.Kind == InstallationStepKind.Validation)
                    {
                        var validation = await ValidateInstallationWithBackendAsync(license.DisplayKey, activateOnMachine);

                        await RunOnDispatcherAsync(() =>
                        {
                            license.PluginName = validation.PluginName;
                            license.ProductId = validation.ProductId;
                            license.Edition = validation.Edition;
                            license.SkipLocalActivation = validation.SkipLocalActivation;
                            license.ActivationUsage = validation.ActivationUsage;
                            license.ProductData = validation.ProductData;
                            license.PurchaseUrl = validation.PurchaseUrl;

                            license.PreviousVersions.Clear();
                            foreach (var v in validation.PreviousVersions)
                            {
                                license.PreviousVersions.Add(v);
                            }
                            return Task.CompletedTask;
                        });

                        latestVersion = validation.TargetVersion;
                        latestReleaseId = validation.TargetReleaseId;

                        var hasExplicitTargetVersion = !string.IsNullOrWhiteSpace(targetVersion);
                        var hasExplicitReleaseId = !string.IsNullOrWhiteSpace(releaseId);
                        if (string.IsNullOrEmpty(resolvedReleaseId) ||
                            (!hasExplicitReleaseId && resolvedReleaseId == "rel_demo_version") ||
                            (!hasExplicitReleaseId && string.IsNullOrEmpty(license.InstalledVersion)))
                        {
                            resolvedReleaseId = validation.TargetReleaseId;
                        }
                        if (string.IsNullOrEmpty(resolvedTargetVersion) ||
                            (!hasExplicitTargetVersion && (resolvedTargetVersion == "1.0.0" || resolvedTargetVersion == "1.1.0")) ||
                            (!hasExplicitTargetVersion && string.IsNullOrEmpty(license.InstalledVersion)))
                        {
                            resolvedTargetVersion = validation.TargetVersion;
                        }
                        license.InstallationTargetVersion = resolvedTargetVersion;
                        successMessage = validation.SuccessMessage;
                    }
                    else if (step.Kind == InstallationStepKind.Download)
                    {
                        var token = _backendService.SessionTokens.TokenFor(license.DisplayKey);
                        var resolved = await _backendService.ResolveDownloadAsync(
                            resolvedReleaseId ?? throw new InvalidOperationException("Release ID is empty."),
                            new ResolveDownloadRequestDto
                            {
                                Platform = "windows",
                                MachineFingerprint = MachineFingerprint
                            },
                            token);

                        step.ProgressValue = 0;
                        step.ProgressText = $"0% of {FormatBytes(resolved.FileSize.GetValueOrDefault())}";

                        var progressHandler = new Progress<DownloadProgress>(progress =>
                        {
                            step.ProgressValue = (int)(progress.Fraction * 100);
                            step.ProgressText = $"{FormatBytes(progress.BytesWritten)} of {FormatBytes(progress.BytesTotal)}";
                        });

                        downloadedZipPath = await _backendService.DownloadFileAsync(
                            resolved.Url,
                            resolved.Name,
                            progressHandler);
                    }
                    else if (step.Kind == InstallationStepKind.Install)
                    {
                        if (string.IsNullOrWhiteSpace(downloadedZipPath) || !File.Exists(downloadedZipPath))
                        {
                            throw new FileNotFoundException("Downloaded installer file not found.");
                        }

                        var installTransaction = await _installService.ExtractAndInstallTransactionalAsync(downloadedZipPath);
                        AttachInstallTransaction(license, installTransaction);
                        var installedBundles = installTransaction.InstalledBundleNames;
                        license.InstalledBundleNames.Clear();
                        if (installedBundles != null && installedBundles.Count > 0)
                        {
                            foreach (var bundleName in installedBundles)
                            {
                                license.InstalledBundleNames.Add(bundleName);
                            }
                        }
                        else
                        {
                            license.InstalledBundleNames.Add($"{license.PluginName}.ofx.bundle");
                        }

                        try
                        {
                            File.Delete(downloadedZipPath);
                        }
                        catch
                        {
                            // Suppress cleanup issues
                        }
                    }
                    else if (step.Kind == InstallationStepKind.Activation)
                    {
                        if (license.SkipLocalActivation)
                        {
                            step.ProgressText = "Bypassing local machine activation";
                        }
                        else if (!activateOnMachine)
                        {
                            step.ProgressText = "License already active on this machine";
                        }
                        else
                        {
                            await _lexService.ActivateAsync(license.ProductId, license.DisplayKey, license.ProductData, MachineFingerprint);
                        }
                    }
                    // Provide a small visual buffer so steps don't flash instantly
                    await Task.Delay(420);

                    step.Status = InstallationStepStatus.Completed;
                }
                catch (Exception error)
                {
                    var userMessage = UserFacingErrorMessage(error);
                    step.Status = InstallationStepStatus.Failed;
                    step.ErrorDetail = $"— {userMessage}";
                    step.ProgressText = userMessage;
                    license.FeedbackMessage = userMessage;
                    license.FeedbackBrush = Brushes.StatusError;
                    license.InstallationFailed = true;
                    IsBusy = false;
                    license.EndWorkflow();
                    RefreshCollectionState();
                    return (false, null, null, null, null, null);
                }
            }

            IsBusy = false;
            license.EndWorkflow();
            RefreshCollectionState();
            return (true, resolvedReleaseId, resolvedTargetVersion, latestVersion, latestReleaseId, successMessage);
        }

        private void AttachInstallTransaction(PluginLicenseItem license, InstallTransaction transaction)
        {
            if (_installationRetryContexts.TryGetValue(license.Id, out var retryContext))
            {
                retryContext.InstallTransaction = transaction;
                return;
            }

            _installService.CommitInstallTransaction(transaction);
        }

        private void CommitPendingInstall(Guid licenseId)
        {
            if (!_installationRetryContexts.TryGetValue(licenseId, out var retryContext))
            {
                return;
            }

            _installService.CommitInstallTransaction(retryContext.InstallTransaction);
            retryContext.InstallTransaction = null;
        }

        private bool RollbackPendingInstall(PluginLicenseItem license, bool restoreStateForRetry)
        {
            if (!_installationRetryContexts.TryGetValue(license.Id, out var retryContext) ||
                retryContext.InstallTransaction == null)
            {
                return true;
            }

            try
            {
                _installService.RollbackInstallTransaction(retryContext.InstallTransaction);
                retryContext.InstallTransaction = null;

                if (restoreStateForRetry)
                {
                    retryContext.RestoreBeforeRetry(license);
                }

                return true;
            }
            catch (Exception ex)
            {
                license.FeedbackMessage = $"Could not restore previous plugin files: {ex.Message}";
                license.FeedbackBrush = Brushes.StatusError;
                license.InstallationFailed = true;
                SetInstallationInteractionLock(true);
                IsBusy = false;
                RefreshCollectionState();
                return false;
            }
        }

        private sealed class InstallationRetryContext
        {
            private InstallationRetryContext(
                PluginLifecycleState previousLifecycleState,
                string? previousInstalledVersion,
                string? previousInstalledReleaseId,
                string? previousAvailableVersion,
                string? previousAvailableReleaseId,
                string? previousDeactivationDate,
                IReadOnlyList<ReleaseVersionInfo> previousVersions,
                IReadOnlyList<string> installedBundleNames,
                string? targetVersion,
                string? targetReleaseId,
                bool isPreviousVersion,
                bool activateOnMachine,
                bool removeLicenseOnCancel)
            {
                PreviousLifecycleState = previousLifecycleState;
                PreviousInstalledVersion = previousInstalledVersion;
                PreviousInstalledReleaseId = previousInstalledReleaseId;
                PreviousAvailableVersion = previousAvailableVersion;
                PreviousAvailableReleaseId = previousAvailableReleaseId;
                PreviousDeactivationDate = previousDeactivationDate;
                PreviousVersions = previousVersions;
                InstalledBundleNames = installedBundleNames;
                TargetVersion = targetVersion;
                TargetReleaseId = targetReleaseId;
                IsPreviousVersion = isPreviousVersion;
                ActivateOnMachine = activateOnMachine;
                RemoveLicenseOnCancel = removeLicenseOnCancel;
            }

            public PluginLifecycleState PreviousLifecycleState { get; }
            public string? PreviousInstalledVersion { get; }
            public string? PreviousInstalledReleaseId { get; }
            public string? PreviousAvailableVersion { get; }
            public string? PreviousAvailableReleaseId { get; }
            public string? PreviousDeactivationDate { get; }
            public IReadOnlyList<ReleaseVersionInfo> PreviousVersions { get; }
            public IReadOnlyList<string> InstalledBundleNames { get; }
            public string? TargetVersion { get; }
            public string? TargetReleaseId { get; }
            public bool IsPreviousVersion { get; }
            public bool ActivateOnMachine { get; }
            public bool RemoveLicenseOnCancel { get; }
            public InstallTransaction? InstallTransaction { get; set; }

            public static InstallationRetryContext Capture(
                PluginLicenseItem license,
                string? targetVersion,
                string? targetReleaseId,
                bool isPreviousVersion,
                bool activateOnMachine)
            {
                var previousVersions = license.PreviousVersions
                    .Select(version => new ReleaseVersionInfo(version.Version, version.Channel, version.ReleaseId))
                    .ToArray();
                var installedBundleNames = license.InstalledBundleNames.ToArray();

                return new InstallationRetryContext(
                    license.LifecycleState,
                    license.InstalledVersion,
                    license.InstalledReleaseId,
                    license.AvailableVersion,
                    license.AvailableReleaseId,
                    license.DeactivationDate,
                    previousVersions,
                    installedBundleNames,
                    targetVersion,
                    targetReleaseId,
                    isPreviousVersion,
                    activateOnMachine,
                    false);
            }

            public static InstallationRetryContext CaptureNewActivation()
            {
                return new InstallationRetryContext(
                    PluginLifecycleState.Idle,
                    null,
                    null,
                    null,
                    null,
                    null,
                    Array.Empty<ReleaseVersionInfo>(),
                    Array.Empty<string>(),
                    null,
                    null,
                    false,
                    true,
                    true);
            }

            public void RestoreOnCancel(PluginLicenseItem license)
            {
                RestoreBaseState(license);
                license.InstallationTargetVersion = null;
                license.InstallationFailed = false;
                license.FeedbackMessage = null;
                license.FeedbackBrush = Brushes.StatusActive;
                license.EndWorkflow();
            }

            public void RestoreBeforeRetry(PluginLicenseItem license)
            {
                RestoreBaseState(license);
            }

            private void RestoreBaseState(PluginLicenseItem license)
            {
                license.InstalledVersion = PreviousInstalledVersion;
                license.InstalledReleaseId = PreviousInstalledReleaseId;
                license.AvailableVersion = PreviousAvailableVersion;
                license.AvailableReleaseId = PreviousAvailableReleaseId;
                license.DeactivationDate = PreviousDeactivationDate;
                license.LifecycleState = PreviousLifecycleState;
                license.IsShowingPreviousVersions = false;

                license.PreviousVersions.Clear();
                foreach (var version in PreviousVersions)
                {
                    license.PreviousVersions.Add(version);
                }

                license.InstalledBundleNames.Clear();
                foreach (var bundleName in InstalledBundleNames)
                {
                    license.InstalledBundleNames.Add(bundleName);
                }

                license.RefreshInstalledBundleActions();
            }
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes <= 0) return "0 B";
            string[] suffix = { "B", "KB", "MB", "GB", "TB" };
            int index = 0;
            double value = bytes;
            while (value >= 1024 && index < suffix.Length - 1)
            {
                value /= 1024;
                index++;
            }
            return $"{value:F1} {suffix[index]}";
        }

        public void CancelInstallationError()
        {
            var license = SelectedLicense;
            if (license == null)
            {
                return;
            }

            if (_installationRetryContexts.TryGetValue(license.Id, out var retryContext))
            {
                if (!RollbackPendingInstall(license, restoreStateForRetry: false))
                {
                    return;
                }

                if (retryContext.RemoveLicenseOnCancel)
                {
                    RemoveFailedActivationAttempt(license);
                    _installationRetryContexts.Remove(license.Id);
                    SetInstallationInteractionLock(false);
                    SaveLicenses();
                    return;
                }

                retryContext.RestoreOnCancel(license);
                _installationRetryContexts.Remove(license.Id);
                SetInstallationInteractionLock(false);
                SaveLicenses();
                return;
            }

            license.EndWorkflow();
            license.InstallationFailed = false;
            license.FeedbackMessage = null;
            license.InstallationTargetVersion = null;
            SetInstallationInteractionLock(false);

            if (string.IsNullOrEmpty(license.ProductId))
            {
                license.LifecycleState = PluginLifecycleState.Deactivating;
                license.InstalledVersion = null;
                license.AvailableVersion = null;
                license.DeactivationDate = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
                SaveLicenses();
                return;
            }

            if (license.InstalledVersion == null)
            {
                license.LifecycleState = PluginLifecycleState.Deactivating;
            }
            else
            {
                license.LifecycleState = !string.IsNullOrEmpty(license.AvailableVersion)
                    ? PluginLifecycleState.UpdateAvailable
                    : PluginLifecycleState.Active;
            }

            SaveLicenses();
        }

        private void RemoveFailedActivationAttempt(PluginLicenseItem license)
        {
            Licenses.Remove(license);
            SelectedLicense = Licenses.Count > 0 ? Licenses[0] : null;
            IsShowingActivationPanel = Licenses.Count == 0;
            RefreshCollectionState();
        }

        public void TogglePreviousVersions()
        {
            if (SelectedLicense != null)
            {
                SelectedLicense.IsShowingPreviousVersions = !SelectedLicense.IsShowingPreviousVersions;
            }
        }

        public void DeactivateSelectedLicense()
        {
            if (SelectedLicense == null)
            {
                return;
            }

            if (!SelectedLicense.SkipLocalActivation)
            {
                try
                {
                    _lexService.Deactivate(SelectedLicense.ProductId, SelectedLicense.ProductData);
                }
                catch
                {
                    // Suppress LexActivator issues on deactivation to always allow local cleanup
                }
            }

            SelectedLicense.LifecycleState = PluginLifecycleState.Deactivating;
            SelectedLicense.DeactivationDate = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
            SelectedLicense.AvailableVersion = null;
            SelectedLicense.AvailableReleaseId = null;
            SelectedLicense.FeedbackMessage = "Plugin files were not removed.";
            SelectedLicense.FeedbackBrush = Brushes.StatusWarning;
            SaveLicenses();
        }

        public void RemovePluginFromSelectedLicense()
        {
            if (SelectedLicense == null)
            {
                return;
            }

            try
            {
                _installService.UninstallBundles(SelectedLicense.InstalledBundleNames);
            }
            catch (Exception ex)
            {
                SelectedLicense.FeedbackMessage = $"Failed to remove plugin files: {ex.Message}";
                SelectedLicense.FeedbackBrush = Brushes.StatusError;
                return;
            }

            SelectedLicense.InstalledBundleNames.Clear();
            SelectedLicense.InstalledVersion = null;
            SelectedLicense.InstalledReleaseId = null;
            SelectedLicense.AvailableVersion = null;
            SelectedLicense.AvailableReleaseId = null;
            SelectedLicense.PreviousVersions.Clear();
            SelectedLicense.IsShowingPreviousVersions = false;
            SelectedLicense.RefreshInstalledBundleActions();
            var wasDeactivated = SelectedLicense.LifecycleState == PluginLifecycleState.Deactivating;
            if (wasDeactivated)
            {
                SelectedLicense.LifecycleState = PluginLifecycleState.Deactivating;
            }
            else if (SelectedLicense.IsRevoked)
            {
                SelectedLicense.LifecycleState = PluginLifecycleState.Deactivating;
            }
            else if (SelectedLicense.LifecycleState == PluginLifecycleState.UpdateAvailable)
            {
                SelectedLicense.LifecycleState = PluginLifecycleState.Active;
            }

            if (wasDeactivated)
            {
                SelectedLicense.DeactivationDate = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture);
            }
            SelectedLicense.FeedbackMessage = "Plugin removed. Your license was not cancelled.";
            SelectedLicense.FeedbackBrush = Brushes.StatusWarning;
            SaveLicenses();
        }

        public void RemoveSelectedLicense()
        {
            if (SelectedLicense == null)
            {
                return;
            }

            var removed = SelectedLicense;
            _installationRetryContexts.Remove(removed.Id);
            Licenses.Remove(removed);
            SelectedLicense = Licenses.Count > 0 ? Licenses[0] : null;
            IsShowingActivationPanel = Licenses.Count == 0;
            RefreshCollectionState();
            SaveLicenses();
        }

        public void RetrySync()
        {
            _ = SyncAllLicensesAsync();
        }

        public async Task SyncAllLicensesAsync()
        {
            if (_isSyncRunning || Licenses.Count == 0)
            {
                return;
            }

            _isSyncRunning = true;
            SyncState = LicenseSyncState.Syncing;
            try
            {
                var items = new List<SyncBatchItemDto>();
                foreach (var l in Licenses)
                {
                    if (l.IsCredentialMissing ||
                        l.LifecycleState == PluginLifecycleState.Deactivating ||
                        l.LifecycleState == PluginLifecycleState.Activating)
                    {
                        continue;
                    }

                    items.Add(new SyncBatchItemDto
                    {
                        Key = l.DisplayKey,
                        SessionToken = _backendService.SessionTokens.TokenFor(l.DisplayKey)
                    });
                }

                if (items.Count == 0)
                {
                    SyncState = LicenseSyncState.Synced;
                    return;
                }

                var results = new List<SyncBatchResultDto>();
                for (var i = 0; i < items.Count; i += MaxSyncBatchItems)
                {
                    var response = await _backendService.SyncBatchAsync(new SyncBatchRequestDto
                    {
                        MachineFingerprint = MachineFingerprint,
                        Items = items.Skip(i).Take(MaxSyncBatchItems).ToList()
                    });
                    results.AddRange(response.Results);
                }

                System.Windows.Application.Current.Dispatcher.Invoke(() =>
                {
                    foreach (var result in results)
                    {
                        var license = Licenses.FirstOrDefault(l => string.Equals(l.DisplayKey, result.Key, StringComparison.OrdinalIgnoreCase));
                        if (license == null) continue;

                        if (result.Ok)
                        {
                            license.IsRevoked = false;
                            license.IsCredentialMissing = false;
                            var oldEdition = license.Edition;
                            var hasPositiveFeedback = false;
                            license.ProductId = result.Product?.ProductId ?? license.ProductId;
                            if (!string.IsNullOrWhiteSpace(result.Product?.Name))
                            {
                                license.PluginName = result.Product.Name;
                            }
                            if (!string.IsNullOrWhiteSpace(result.Product?.ProductData))
                            {
                                license.ProductData = result.Product.ProductData;
                            }
                            if (!string.IsNullOrWhiteSpace(result.Product?.PurchaseUrl))
                            {
                                license.PurchaseUrl = result.Product.PurchaseUrl;
                            }
                            license.Edition = EditionFromBackend(result.Edition ?? "full");
                            license.ActivationUsage = result.ActivationUsage ?? license.ActivationUsage;
                            if (result.SkipLocalActivation.HasValue)
                            {
                                license.SkipLocalActivation = result.SkipLocalActivation.Value;
                            }

                            if (oldEdition == LicenseEdition.Trial && license.Edition == LicenseEdition.Full)
                            {
                                license.FeedbackMessage = "Upgraded to Full!";
                                license.FeedbackBrush = Brushes.StatusActive;
                                hasPositiveFeedback = true;
                            }
                            else if (!string.IsNullOrWhiteSpace(result.Message?.Message))
                            {
                                license.FeedbackMessage = result.Message.Message;
                                license.FeedbackBrush = Brushes.StatusActive;
                                hasPositiveFeedback = true;
                            }

                            if (!string.IsNullOrWhiteSpace(result.SessionToken) && result.ExpiresIn.GetValueOrDefault() > 0)
                            {
                                _backendService.SessionTokens.Store(result.SessionToken, result.ExpiresIn.Value, result.Key);
                            }

                            // Sync releases
                            if (result.Releases != null)
                            {
                                var releases = result.Releases
                                    .Where(release => string.Equals(release.Platform, "windows", StringComparison.OrdinalIgnoreCase))
                                    .Select(release => new ReleaseVersionInfo(release.Version, string.IsNullOrWhiteSpace(release.Channel) ? "stable" : release.Channel!, release.Id))
                                    .Where(release => !string.IsNullOrWhiteSpace(release.Version))
                                    .GroupBy(release => release.Version, StringComparer.OrdinalIgnoreCase)
                                    .Select(group => group.First())
                                    .OrderByDescending(release => release.Version, VersionSortKeyComparer.Instance)
                                    .ToList();

                                if (releases.Count > 0)
                                {
                                    var latest = releases[0];
                                    var previousVersions = releases.Skip(1).ToArray();

                                    // Update previous versions collection on the license
                                    license.PreviousVersions.Clear();
                                    foreach (var prev in previousVersions)
                                    {
                                        license.PreviousVersions.Add(prev);
                                    }

                                    // Check if we have an update
                                    var installedVer = license.InstalledVersion;
                                    if (!string.IsNullOrWhiteSpace(installedVer) && 
                                        VersionSortKeyComparer.Instance.Compare(latest.Version, installedVer) > 0)
                                    {
                                        license.AvailableVersion = latest.Version;
                                        license.AvailableReleaseId = latest.ReleaseId;
                                        
                                        // If currently active, change status to UpdateAvailable
                                        if (license.LifecycleState == PluginLifecycleState.Active)
                                        {
                                            license.LifecycleState = PluginLifecycleState.UpdateAvailable;
                                        }
                                    }
                                    else
                                    {
                                        license.AvailableVersion = null;
                                        license.AvailableReleaseId = null;
                                        if (license.LifecycleState == PluginLifecycleState.UpdateAvailable)
                                        {
                                            license.LifecycleState = PluginLifecycleState.Active;
                                        }
                                    }
                                }
                            }

                            // Update lifecycle state based on backend status
                            if (result.Status == "suspended")
                            {
                                license.LifecycleState = PluginLifecycleState.Suspended;
                            }
                            else if (result.Status == "revoked" || result.Status == "expired")
                            {
                                MarkLicenseRevoked(license);
                            }
                            else if (result.Status == "active")
                            {
                                if (license.LifecycleState == PluginLifecycleState.Suspended)
                                {
                                    license.LifecycleState = license.AvailableVersion != null ? PluginLifecycleState.UpdateAvailable : PluginLifecycleState.Active;
                                }
                            }

                            if (!hasPositiveFeedback &&
                                !license.InstallationFailed &&
                                license.LifecycleState is PluginLifecycleState.Active or PluginLifecycleState.UpdateAvailable)
                            {
                                license.ClearWarningOrErrorFeedback();
                            }
                        }
                        else
                        {
                            // Handle item error
                            if (result.Error != null)
                            {
                                if (!string.IsNullOrWhiteSpace(result.Error.Message))
                                {
                                    license.FeedbackMessage = result.Error.Message;
                                    license.FeedbackBrush = Brushes.StatusError;
                                }

                                if (result.Error.Code == "license_not_found" || result.Error.Code == "license_revoked")
                                {
                                    MarkLicenseRevoked(license, result.Error.Message);
                                }
                                else if (result.Error.Code == "license_suspended")
                                {
                                    license.LifecycleState = PluginLifecycleState.Suspended;
                                }
                            }
                        }
                    }

                    SyncState = LicenseSyncState.Synced;
                    _hasSyncNotice = false;
                    _lastSuccessfulSyncDate = DateTime.Now;
                    OnPropertyChanged(nameof(SyncNoticeVisibility));
                    OnPropertyChanged(nameof(LastUpdatedText));
                    SaveLicenses();
                });
            }
            catch (Exception ex)
            {
                System.Windows.Application.Current.Dispatcher.Invoke(() =>
                {
                    SyncState = LicenseSyncState.Failed;
                    _hasSyncNotice = true;
                    _syncNoticeMessage = UserFacingErrorMessage(ex);
                    SupportCodeText = ex is AppBackendException backendError
                        ? SupportCodeFor(backendError)
                        : "SYNC_BATCH_FAILED";
                    OnPropertyChanged(nameof(SyncNoticeMessage));
                    OnPropertyChanged(nameof(SyncNoticeVisibility));
                });
                _ = ex;
            }
            finally
            {
                _isSyncRunning = false;
            }
        }

        private void RefreshCardSelection()
        {
            foreach (var license in Licenses)
            {
                license.IsSelected = ReferenceEquals(license, SelectedLicense);
            }

            OnPropertyChanged(nameof(DiagnosticsPayload));
        }

        private void RefreshCollectionState()
        {
            OnPropertyChanged(nameof(LicenseListVisibility));
            OnPropertyChanged(nameof(EmptyLicensesVisibility));
            OnPropertyChanged(nameof(SelectedLicenseVisibility));
        }

        private void SaveLicenses()
        {
            _storageService.Save(Licenses);
        }

        private void SetInstallationInteractionLock(bool isLocked)
        {
            if (_isInstallationInteractionLocked == isLocked)
            {
                return;
            }

            _isInstallationInteractionLocked = isLocked;
            OnPropertyChanged(nameof(CanInteract));
            OnPropertyChanged(nameof(CanActivate));
            OnPropertyChanged(nameof(CanRetrySync));
        }

        private static void NormalizeInterruptedInstallation(PluginLicenseItem license)
        {
            if (license.LifecycleState != PluginLifecycleState.Activating)
            {
                return;
            }

            license.InstallationFailed = false;
            license.FeedbackMessage = null;
            license.FeedbackBrush = Brushes.StatusActive;
            license.InstallationTargetVersion = null;
            license.LifecycleState = !string.IsNullOrWhiteSpace(license.InstalledVersion)
                ? string.IsNullOrWhiteSpace(license.AvailableVersion)
                    ? PluginLifecycleState.Active
                    : PluginLifecycleState.UpdateAvailable
                : PluginLifecycleState.Deactivating;
        }

        private static LicenseEdition EditionFromBackend(string edition)
        {
            return edition.Trim().ToLowerInvariant() switch
            {
                "trial" or "demo" => LicenseEdition.Trial,
                "beta" => LicenseEdition.Beta,
                _ => LicenseEdition.Full
            };
        }

        private static string ActivationErrorMessageFor(AppBackendException error)
        {
            if (string.Equals(error.Payload?.Code, "activation_limit_reached", StringComparison.OrdinalIgnoreCase))
            {
                return "No activations are available for this license. Deactivate another machine or contact support.";
            }

            if (error.Payload is not null && !string.IsNullOrWhiteSpace(error.Payload.Message))
            {
                return error.Payload.Message;
            }

            if (error.StatusCode == HttpStatusCode.TooManyRequests)
            {
                return "Too many requests. Please try again later.";
            }

            if (error.StatusCode == HttpStatusCode.Unauthorized || error.StatusCode == HttpStatusCode.Forbidden)
            {
                return "This license cannot be activated on this machine.";
            }

            if (error.StatusCode == HttpStatusCode.NotFound)
            {
                return "No Windows release is available for this license.";
            }

            return error.Kind switch
            {
                AppBackendErrorKind.Transport => "Could not reach the license service. Please check your connection and try again.",
                AppBackendErrorKind.Decoding => "The license service returned an unexpected response. Please try again.",
                AppBackendErrorKind.InvalidUrl or AppBackendErrorKind.MissingConfiguration => "License service is not configured correctly.",
                _ => "Could not validate this license. Please try again."
            };
        }

        private static string UserFacingErrorMessage(Exception error)
        {
            if (error is AppBackendException backendError)
            {
                return ActivationErrorMessageFor(backendError);
            }

            return string.IsNullOrWhiteSpace(error.Message)
                ? "Unexpected error, please contact support"
                : error.Message;
        }

        private static string SupportCodeFor(AppBackendException error)
        {
            if (error.Payload is not null && !string.IsNullOrWhiteSpace(error.Payload.Code))
            {
                return error.Payload.Code.ToUpperInvariant();
            }

            if (error.StatusCode is not null)
            {
                return $"LICENSE_HTTP_{(int)error.StatusCode.Value}";
            }

            return error.Kind switch
            {
                AppBackendErrorKind.Transport => "LICENSE_SERVICE_UNAVAILABLE",
                AppBackendErrorKind.Decoding => "LICENSE_RESPONSE_INVALID",
                _ => "LICENSE_VALIDATE_FAILED"
            };
        }

        private sealed record BackendActivationValidation(
            string PluginName,
            string ProductId,
            LicenseEdition Edition,
            string TargetVersion,
            string TargetReleaseId,
            string ActivationUsage,
            ReleaseVersionInfo[] PreviousVersions,
            string? SuccessMessage,
            bool SkipLocalActivation,
            string? ProductData,
            string? PurchaseUrl);

        private sealed class VersionSortKeyComparer : IComparer<string>
        {
            public static VersionSortKeyComparer Instance { get; } = new();

            public int Compare(string? x, string? y)
            {
                var left = NumericVersionComponents(x ?? string.Empty);
                var right = NumericVersionComponents(y ?? string.Empty);
                var max = Math.Max(left.Length, right.Length);

                for (var index = 0; index < max; index++)
                {
                    var leftPart = index < left.Length ? left[index] : 0;
                    var rightPart = index < right.Length ? right[index] : 0;

                    if (leftPart != rightPart)
                    {
                        return leftPart.CompareTo(rightPart);
                    }
                }

                return string.Compare(x, y, StringComparison.OrdinalIgnoreCase);
            }

            private static int[] NumericVersionComponents(string raw)
            {
                return raw
                    .Trim()
                    .Split('.', StringSplitOptions.RemoveEmptyEntries)
                    .Select(LeadingNumber)
                    .ToArray();
            }

            private static int LeadingNumber(string segment)
            {
                var length = 0;
                while (length < segment.Length && char.IsAsciiDigit(segment[length]))
                {
                    length++;
                }

                return length == 0 || !int.TryParse(segment[..length], out var value) ? 0 : value;
            }
        }
    }
}
