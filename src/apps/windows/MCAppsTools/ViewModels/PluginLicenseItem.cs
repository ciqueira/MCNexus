using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Windows;
using System.Windows.Media;

namespace MCAppsTools
{
    public sealed class PluginLicenseItem : NotifyObject
    {
        private string _pluginName = string.Empty;
        private string _productId = string.Empty;
        private LicenseEdition _edition;
        private PluginLifecycleState _lifecycleState;
        private string? _installedVersion;
        private string? _installedReleaseId;
        private string? _availableVersion;
        private string? _availableReleaseId;
        private string? _installationTargetVersion;
        private string _displayKey = string.Empty;
        private string _licenseKeyHash = string.Empty;
        private string _activationDate = string.Empty;
        private string _pluginUpdateDate = string.Empty;
        private string? _deactivationDate;
        private string _activationUsage = string.Empty;
        private bool _isSelected;
        private bool _isShowingPreviousVersions;
        private bool _installationFailed;
        private bool _isCredentialMissing;
        private bool _isRevoked;
        private string? _feedbackMessage;
        private Brush _feedbackBrush = Brushes.StatusActive;
        private bool _skipLocalActivation;
        private string? _productData;
        private string? _purchaseUrl;
        private LicenseRuntime? _runtime;
        private string? _tenantId;
        private string? _activationId;

        public ObservableCollection<ReleaseVersionInfo> PreviousVersions { get; } = new();
        public ObservableCollection<InstallationStepViewModel> InstallationSteps { get; } = new();
        public ObservableCollection<string> InstalledBundleNames { get; } = new();
        public ObservableCollection<LicenseActionItem> ActionItems { get; } = new();

        public static PluginLicenseItem Create(
            Guid id,
            string pluginName,
            string productId,
            LicenseEdition edition,
            PluginLifecycleState state,
            string key,
            string? installedVersion,
            string? installedReleaseId,
            string? availableVersion,
            string? availableReleaseId,
            string activationDate,
            string pluginUpdateDate,
            string activationUsage,
            ReleaseVersionInfo[] previousVersions,
            IReadOnlyCollection<string>? installedBundleNames,
            Action? beginActivationCallback = null,
            bool skipLocalActivation = false,
            string? productData = null,
            string? purchaseUrl = null,
            LicenseRuntime? runtime = null,
            string? tenantId = null,
            string? activationId = null)
        {
            var item = new PluginLicenseItem
            {
                Id = id,
                PluginName = pluginName,
                ProductId = productId,
                Edition = edition,
                LifecycleState = state,
                DisplayKey = key,
                LicenseKeyHash = LicenseKeyIdentity.IsSignedKey(key) ? LicenseKeyIdentity.Hash(LicenseKeyIdentity.Normalize(key)) : string.Empty,
                IsCredentialMissing = string.IsNullOrWhiteSpace(key),
                InstalledVersion = installedVersion,
                InstalledReleaseId = installedReleaseId,
                AvailableVersion = availableVersion,
                AvailableReleaseId = availableReleaseId,
                ActivationDate = activationDate,
                PluginUpdateDate = pluginUpdateDate,
                ActivationUsage = activationUsage,
                SkipLocalActivation = skipLocalActivation,
                ProductData = productData,
                PurchaseUrl = purchaseUrl,
                Runtime = runtime,
                TenantId = tenantId,
                ActivationId = activationId
            };

            if (installedBundleNames == null || installedBundleNames.Count == 0)
            {
                item.InstalledBundleNames.Add($"{pluginName}.ofx.bundle");
            }
            else
            {
                foreach (var bundleName in installedBundleNames)
                {
                    item.InstalledBundleNames.Add(bundleName);
                }
            }

            foreach (var version in previousVersions)
            {
                item.PreviousVersions.Add(version);
            }

            item.ResetSteps();
            item.RebuildActionItems();
            return item;
        }

        public static PluginLicenseItem Create(
            string pluginName,
            string productId,
            LicenseEdition edition,
            PluginLifecycleState state,
            string key,
            string? installedVersion,
            string? installedReleaseId,
            string? availableVersion,
            string? availableReleaseId,
            string activationDate,
            string pluginUpdateDate,
            string activationUsage,
            ReleaseVersionInfo[] previousVersions,
            bool skipLocalActivation = false,
            string? productData = null,
            string? purchaseUrl = null)
        {
            return Create(
                Guid.NewGuid(),
                pluginName,
                productId,
                edition,
                state,
                key,
                installedVersion,
                installedReleaseId,
                availableVersion,
                availableReleaseId,
                activationDate,
                pluginUpdateDate,
                activationUsage,
                previousVersions,
                null,
                null,
                skipLocalActivation,
                productData,
                purchaseUrl);
        }

        public Guid Id { get; private set; }

        public bool SkipLocalActivation
        {
            get => _skipLocalActivation;
            set => SetProperty(ref _skipLocalActivation, value);
        }

        public string? ProductData
        {
            get => _productData;
            set => SetProperty(ref _productData, value);
        }

        public string? PurchaseUrl
        {
            get => _purchaseUrl;
            set => SetProperty(ref _purchaseUrl, value);
        }

        /// <summary>
        /// Which local SDK this license's activation is routed through
        /// (Fase 5, D41). <c>null</c> means "never reported by the backend"
        /// — decodes the same as a pre-schema-2 record and resolves to
        /// Cryptlex via <see cref="LicenseRuntimeRouter"/>.
        /// </summary>
        public LicenseRuntime? Runtime
        {
            get => _runtime;
            set => SetProperty(ref _runtime, value);
        }

        /// <summary>Required by NexKeyRuntime's set_tenant_id before load_local; unused by Cryptlex.</summary>
        public string? TenantId
        {
            get => _tenantId;
            set => SetProperty(ref _tenantId, value);
        }

        /// <summary>
        /// NexKeyRuntime's own identifier for the local activation, so
        /// ownership survives a relaunch (its ABI never hands the raw key
        /// back). Cryptlex has no equivalent and leaves this null.
        /// </summary>
        public string? ActivationId
        {
            get => _activationId;
            set => SetProperty(ref _activationId, value);
        }

        public string PluginName
        {
            get => _pluginName;
            set => SetProperty(ref _pluginName, value);
        }

        public string ProductId
        {
            get => _productId;
            set => SetProperty(ref _productId, value);
        }

        public LicenseEdition Edition
        {
            get => _edition;
            set
            {
                if (SetProperty(ref _edition, value))
                {
                    OnPropertyChanged(nameof(EditionBadge));
                    OnPropertyChanged(nameof(DetailBadge));
                    OnPropertyChanged(nameof(EditionBrush));
                    OnPropertyChanged(nameof(EditionBadgeVisibility));
                    OnPropertyChanged(nameof(DetailBadgeVisibility));
                }
            }
        }

        public PluginLifecycleState LifecycleState
        {
            get => _lifecycleState;
            set
            {
                if (SetProperty(ref _lifecycleState, value))
                {
                    ClearStaleFeedbackForHealthyState();
                    OnStatusChanged();
                }
            }
        }

        public string? InstalledVersion
        {
            get => _installedVersion;
            set
            {
                if (SetProperty(ref _installedVersion, value))
                {
                    OnPropertyChanged(nameof(InstalledVersionText));
                    OnPropertyChanged(nameof(InstalledVersionValue));
                    OnPropertyChanged(nameof(FilteredPreviousVersions));
                    OnPropertyChanged(nameof(HasInstalledPlugin));
                    OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
                    OnPropertyChanged(nameof(IsPluginRemoved));
                    OnStatusChanged();
                }
            }
        }

        public string? InstalledReleaseId
        {
            get => _installedReleaseId;
            set => SetProperty(ref _installedReleaseId, value);
        }

        public string? AvailableVersion
        {
            get => _availableVersion;
            set
            {
                if (SetProperty(ref _availableVersion, value))
                {
                    OnPropertyChanged(nameof(AvailableVersionText));
                    OnPropertyChanged(nameof(AvailableVersionVisibility));
                    OnPropertyChanged(nameof(NewVersionText));
                    OnPropertyChanged(nameof(NewVersionVisibility));
                    OnPropertyChanged(nameof(PrimaryActionText));
                    OnPropertyChanged(nameof(FilteredPreviousVersions));
                }
            }
        }

        public string? AvailableReleaseId
        {
            get => _availableReleaseId;
            set => SetProperty(ref _availableReleaseId, value);
        }

        public string? InstallationTargetVersion
        {
            get => _installationTargetVersion;
            set
            {
                if (SetProperty(ref _installationTargetVersion, value))
                {
                    OnPropertyChanged(nameof(InstallationTargetText));
                    OnPropertyChanged(nameof(InstallationTargetVisibility));
                }
            }
        }

        public string DisplayKey
        {
            get => _displayKey;
            set
            {
                if (SetProperty(ref _displayKey, value))
                {
                    OnPropertyChanged(nameof(SecondaryText));
                    OnPropertyChanged(nameof(LicenseDisplayText));
                    OnPropertyChanged(nameof(HasSavedLicense));
                    OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
                }
            }
        }

        public string LicenseKeyHash
        {
            get => _licenseKeyHash;
            set => SetProperty(ref _licenseKeyHash, value);
        }

        public bool IsCredentialMissing
        {
            get => _isCredentialMissing;
            set
            {
                if (SetProperty(ref _isCredentialMissing, value))
                {
                    OnPropertyChanged(nameof(HasSavedLicense));
                    OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
                    OnPropertyChanged(nameof(IsPluginRemoved));
                    OnStatusChanged();
                    RebuildActionItems();
                    OnPropertyChanged(nameof(LicenseDisplayText));
                }
            }
        }

        public string ActivationDate
        {
            get => _activationDate;
            set => SetProperty(ref _activationDate, value);
        }

        public string PluginUpdateDate
        {
            get => _pluginUpdateDate;
            set => SetProperty(ref _pluginUpdateDate, value);
        }

        public string? DeactivationDate
        {
            get => _deactivationDate;
            set
            {
                if (SetProperty(ref _deactivationDate, value))
                {
                    OnPropertyChanged(nameof(DeactivationDateVisibility));
                }
            }
        }

        public string ActivationUsage
        {
            get => _activationUsage;
            set => SetProperty(ref _activationUsage, value);
        }

        public bool IsSelected
        {
            get => _isSelected;
            set
            {
                if (SetProperty(ref _isSelected, value))
                {
                    OnPropertyChanged(nameof(CardBackground));
                }
            }
        }

        public bool IsShowingPreviousVersions
        {
            get => _isShowingPreviousVersions;
            set
            {
                if (SetProperty(ref _isShowingPreviousVersions, value))
                {
                    OnPropertyChanged(nameof(PreviousVersionsVisibility));
                    OnPropertyChanged(nameof(PreviousVersionsChevron));
                }
            }
        }

        public bool InstallationFailed
        {
            get => _installationFailed;
            set
            {
                if (SetProperty(ref _installationFailed, value))
                {
                    OnPropertyChanged(nameof(InstallationFailedActionsVisibility));
                    OnStatusChanged();
                }
            }
        }

        public bool IsRevoked
        {
            get => _isRevoked;
            set
            {
                if (SetProperty(ref _isRevoked, value))
                {
                    OnPropertyChanged(nameof(IsCorrupted));
                    OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
                    OnPropertyChanged(nameof(IsPluginRemoved));
                    OnStatusChanged();
                }
            }
        }
        public bool IsCorrupted => IsCredentialMissing && !IsRevoked;
        public bool HasInstalledPlugin => !string.IsNullOrWhiteSpace(InstalledVersion);
        public bool HasSavedLicense => !IsCredentialMissing && !string.IsNullOrWhiteSpace(DisplayKey);
        public bool IsPluginMissing =>
            (LifecycleState is PluginLifecycleState.Active or PluginLifecycleState.UpdateAvailable) &&
            !IsCorrupted &&
            !IsRevoked &&
            HasSavedLicense &&
            !HasInstalledPlugin;
        public bool IsLicenseRemovedOnThisMachine =>
            LifecycleState == PluginLifecycleState.Deactivating &&
            !IsCorrupted &&
            !IsRevoked &&
            HasSavedLicense &&
            HasInstalledPlugin;
        public bool IsPluginRemoved =>
            LifecycleState == PluginLifecycleState.Deactivating &&
            !IsCorrupted &&
            !IsRevoked &&
            !HasInstalledPlugin;

        public string? FeedbackMessage
        {
            get => _feedbackMessage;
            set
            {
                if (SetProperty(ref _feedbackMessage, value))
                {
                    OnPropertyChanged(nameof(FeedbackVisibility));
                }
            }
        }

        public Brush FeedbackBrush
        {
            get => _feedbackBrush;
            set => SetProperty(ref _feedbackBrush, value);
        }

        public string EditionBadge => Edition switch
        {
            LicenseEdition.Trial => "Demo",
            LicenseEdition.Beta => "Beta",
            _ => string.Empty
        };

        public string DetailBadge => EditionBadge;
        public Visibility EditionBadgeVisibility => string.IsNullOrWhiteSpace(EditionBadge) ? Visibility.Collapsed : Visibility.Visible;
        public Visibility DetailBadgeVisibility => EditionBadgeVisibility;

        public Brush EditionBrush => Edition switch
        {
            LicenseEdition.Beta => Brushes.StatusWarning,
            LicenseEdition.Trial => Brushes.StatusInfo,
            _ => Brushes.StatusActive
        };

        public Brush CardBackground => IsSelected ? Brushes.PanelSelected : Brushes.PanelSurface;

        public string SecondaryText => LifecycleState switch
        {
            PluginLifecycleState.Suspended => "License suspended",
            _ when IsPluginMissing => "Plugin not installed",
            PluginLifecycleState.Deactivating => IsCorrupted
                ? "Corrupted license"
                : IsRevoked
                    ? "License unavailable"
                    : "License not active",
            _ => DisplayKey
        };

        public Brush SecondaryBrush => LifecycleState switch
        {
            PluginLifecycleState.Suspended => Brushes.StatusWarning,
            _ when IsPluginMissing => Brushes.StatusWarning,
            PluginLifecycleState.Deactivating => IsCorrupted || IsRevoked ? Brushes.StatusError : Brushes.StatusWarning,
            _ => Brushes.TextMuted
        };

        public string InstalledVersionText => $"Version {InstalledVersion ?? "--"}";
        public string InstalledVersionValue => InstalledVersion ?? "--";
        public string AvailableVersionText => $"New: {AvailableVersion}";
        public Visibility AvailableVersionVisibility => string.IsNullOrWhiteSpace(AvailableVersion) ? Visibility.Collapsed : Visibility.Visible;
        public string LicenseDisplayText => IsCredentialMissing ? "Key missing" : DisplayKey;

        public string StatusTitle => LifecycleState switch
        {
            PluginLifecycleState.Active => IsPluginMissing ? "Plugin not installed" : "Active",
            PluginLifecycleState.UpdateAvailable => IsPluginMissing ? "Plugin not installed" : "Update",
            PluginLifecycleState.Suspended => "Suspended",
            PluginLifecycleState.Deactivating => IsCorrupted
                ? "License issue"
                : IsRevoked
                    ? "License unavailable"
                    : "License not active",
            PluginLifecycleState.Activating => "Activating",
            _ => "Not activated"
        };

        public string StatusMessage => LifecycleState switch
        {
            PluginLifecycleState.Active => IsPluginMissing ? "Run installation again." : "Plugin installed and unlocked.",
            PluginLifecycleState.UpdateAvailable => IsPluginMissing ? "Run installation again." : "New version available.",
            PluginLifecycleState.Suspended => "Contact support.",
            PluginLifecycleState.Deactivating => IsCorrupted
                ? "The saved license data cannot be used."
                : IsRevoked
                    ? "This key is no longer valid."
                    : HasInstalledPlugin
                        ? "The plugin is still installed."
                        : "Run installation again.",
            PluginLifecycleState.Activating => "Installing plugin...",
            _ => "Enter your key to unlock the plugin."
        };

        public string StatusIcon => LifecycleState switch
        {
            PluginLifecycleState.Active => IsPluginMissing ? "\uE7BA" : "\uE930",
            PluginLifecycleState.UpdateAvailable => IsPluginMissing ? "\uE7BA" : "\uE896",
            PluginLifecycleState.Suspended => "\uE7BA",
            PluginLifecycleState.Deactivating => "\uE785",
            PluginLifecycleState.Activating => "\uE823",
            _ => "\uE192"
        };

        public Brush StatusBrush => LifecycleState switch
        {
            PluginLifecycleState.Active => IsPluginMissing ? Brushes.StatusWarning : Brushes.StatusActive,
            PluginLifecycleState.UpdateAvailable => Brushes.StatusWarning,
            PluginLifecycleState.Suspended => Brushes.StatusWarning,
            PluginLifecycleState.Deactivating => IsCorrupted || IsRevoked ? Brushes.StatusError : Brushes.StatusWarning,
            PluginLifecycleState.Activating => Brushes.StatusInfo,
            _ => Brushes.StatusIdle
        };

        public Brush StatusBadgeBackground => Brushes.WithOpacity(StatusBrush, 0x1F);
        public Visibility ActivationsVisibility => LifecycleState == PluginLifecycleState.Deactivating ? Visibility.Collapsed : Visibility.Visible;
        public Visibility InstallationProgressVisibility => LifecycleState == PluginLifecycleState.Activating ? Visibility.Visible : Visibility.Collapsed;
        public string InstallationTargetText => string.IsNullOrWhiteSpace(InstallationTargetVersion)
            ? "Preparing installation..."
            : $"Installing version {InstallationTargetVersion}";
        public Visibility InstallationTargetVisibility => LifecycleState == PluginLifecycleState.Activating ? Visibility.Visible : Visibility.Collapsed;
        public Visibility DetailsVisibility => LifecycleState == PluginLifecycleState.Activating ? Visibility.Collapsed : Visibility.Visible;
        public string NewVersionText => $"New: {AvailableVersion}";
        public Visibility NewVersionVisibility => string.IsNullOrWhiteSpace(AvailableVersion) ? Visibility.Collapsed : Visibility.Visible;
        public Visibility FeedbackVisibility => string.IsNullOrWhiteSpace(FeedbackMessage) ? Visibility.Collapsed : Visibility.Visible;
        public Visibility DeactivationDateVisibility => LifecycleState == PluginLifecycleState.Deactivating && !string.IsNullOrWhiteSpace(DeactivationDate) ? Visibility.Visible : Visibility.Collapsed;
        public Visibility PreviousVersionsSectionVisibility => LifecycleState is PluginLifecycleState.Deactivating or PluginLifecycleState.Suspended ? Visibility.Collapsed : (FilteredPreviousVersions.Count > 0 ? Visibility.Visible : Visibility.Collapsed);
        public Visibility PreviousVersionsVisibility => IsShowingPreviousVersions ? Visibility.Visible : Visibility.Collapsed;
        public string PreviousVersionsChevron => IsShowingPreviousVersions ? "\uE70E" : "\uE70D";
        public Visibility InstallationFailedActionsVisibility => InstallationFailed ? Visibility.Visible : Visibility.Collapsed;
        public Visibility SuspendedActionsVisibility => LifecycleState == PluginLifecycleState.Suspended ? Visibility.Visible : Visibility.Collapsed;

        /// <summary>
        /// Mirrors macOS filteredPreviousVersions(for:):
        /// Excludes the currently installed version and the highest known version (latest),
        /// deduplicates by version string, and caps the list at 5 entries.
        /// </summary>
        public IReadOnlyList<ReleaseVersionInfo> FilteredPreviousVersions
        {
            get
            {
                // Determine the highest known version across installed, available and all previous
                var allVersions = new List<string>();
                if (!string.IsNullOrWhiteSpace(InstalledVersion)) allVersions.Add(InstalledVersion!);
                if (!string.IsNullOrWhiteSpace(AvailableVersion)) allVersions.Add(AvailableVersion!);
                foreach (var p in PreviousVersions)
                {
                    if (!string.IsNullOrWhiteSpace(p.Version)) allVersions.Add(p.Version);
                }

                var latestKnown = HighestVersionOf(allVersions);

                var seen = new System.Collections.Generic.HashSet<string>(StringComparer.OrdinalIgnoreCase);
                var result = new List<ReleaseVersionInfo>();
                foreach (var info in PreviousVersions)
                {
                    if (string.IsNullOrWhiteSpace(info.Version)) continue;
                    if (!seen.Add(info.Version)) continue;  // deduplicate
                    if (string.Equals(info.Version, InstalledVersion, StringComparison.OrdinalIgnoreCase)) continue;
                    if (!string.IsNullOrWhiteSpace(latestKnown) &&
                        string.Equals(info.Version, latestKnown, StringComparison.OrdinalIgnoreCase)) continue;
                    result.Add(info);
                    if (result.Count >= 5) break;
                }
                return result;
            }
        }

        public static string? HighestVersionOf(IEnumerable<string> versions)
        {
            string? best = null;
            foreach (var v in versions)
            {
                if (string.IsNullOrWhiteSpace(v)) continue;
                if (best == null)
                {
                    best = v;
                    continue;
                }
                // Compare numerically: split on '.' and compare segment by segment
                var vParts = v.Split('.');
                var bParts = best.Split('.');
                var len = Math.Max(vParts.Length, bParts.Length);
                for (var i = 0; i < len; i++)
                {
                    int vSeg = i < vParts.Length && int.TryParse(vParts[i], out var vp) ? vp : 0;
                    int bSeg = i < bParts.Length && int.TryParse(bParts[i], out var bp) ? bp : 0;
                    if (vSeg > bSeg) { best = v; break; }
                    if (vSeg < bSeg) break;
                }
            }
            return best;
        }

        public Visibility MainActionsVisibility => LifecycleState is PluginLifecycleState.Activating or PluginLifecycleState.Suspended ? Visibility.Collapsed : Visibility.Visible;
        public Visibility ActionItemsVisibility => ActionItems.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

        public string PrimaryActionText => LifecycleState switch
        {
            PluginLifecycleState.UpdateAvailable => IsPluginMissing ? "Reinstall Plugin" : $"Update Available ({AvailableVersion ?? "--"})",
            PluginLifecycleState.Deactivating => InstallationFailed ? "Retry Installation" : "Reactivate License",
            _ when IsPluginMissing => "Reinstall Plugin",
            _ => string.Empty
        };

        public Brush PrimaryActionBrush => LifecycleState == PluginLifecycleState.UpdateAvailable ? Brushes.StatusWarning : Brushes.StatusInfo;
        public Visibility PrimaryActionVisibility =>
            LifecycleState == PluginLifecycleState.UpdateAvailable ||
            (LifecycleState == PluginLifecycleState.Deactivating && !IsCorrupted && !IsRevoked) ||
            IsPluginMissing
                ? Visibility.Visible
                : Visibility.Collapsed;

        public string SecondaryActionText => LifecycleState == PluginLifecycleState.Deactivating || IsRevoked ? "Remove Key" : "Deactivate License";
        public Visibility SecondaryActionVisibility => Visibility.Visible;
        public Visibility RemovePluginVisibility => HasInstalledPlugin ? Visibility.Visible : Visibility.Collapsed;
        public string? DeactivationErrorDetail { get; set; }
        public Visibility DeactivationErrorVisibility => string.IsNullOrWhiteSpace(DeactivationErrorDetail) ? Visibility.Collapsed : Visibility.Visible;

        public void BeginWorkflow()
        {
            FeedbackMessage = null;
            InstallationFailed = false;
            ResetSteps();
            OnStatusChanged();
        }

        public void EndWorkflow()
        {
            OnStatusChanged();
        }

        public void ClearWarningOrErrorFeedback()
        {
            if (ReferenceEquals(FeedbackBrush, Brushes.StatusError) ||
                ReferenceEquals(FeedbackBrush, Brushes.StatusWarning))
            {
                FeedbackMessage = null;
                FeedbackBrush = Brushes.StatusActive;
            }
        }

        public void RefreshInstalledBundleActions()
        {
            OnPropertyChanged(nameof(HasInstalledPlugin));
            OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
            OnPropertyChanged(nameof(IsPluginRemoved));
            OnPropertyChanged(nameof(IsPluginMissing));
            OnStatusChanged();
        }

        private void RebuildActionItems()
        {
            ActionItems.Clear();

            if (InstallationFailed || LifecycleState is PluginLifecycleState.Activating or PluginLifecycleState.Suspended)
            {
                OnPropertyChanged(nameof(ActionItemsVisibility));
                return;
            }

            if (IsRevoked)
            {
                ActionItems.Add(LicenseActionItem.Secondary("Online Support", LicenseActionKind.OnlineSupport));
                ActionItems.Add(LicenseActionItem.Secondary("Remove Key", LicenseActionKind.RemoveKey));
                OnPropertyChanged(nameof(ActionItemsVisibility));
                return;
            }

            if (IsCorrupted)
            {
                ActionItems.Add(LicenseActionItem.Secondary("Remove Key", LicenseActionKind.RemoveKey));
                if (HasInstalledPlugin)
                {
                    ActionItems.Add(LicenseActionItem.Secondary("Remove Plugin", LicenseActionKind.RemovePlugin));
                }
                OnPropertyChanged(nameof(ActionItemsVisibility));
                return;
            }

            if (LifecycleState == PluginLifecycleState.UpdateAvailable && HasInstalledPlugin)
            {
                ActionItems.Add(LicenseActionItem.Primary(
                    $"Update Available ({AvailableVersion ?? "--"})",
                    LicenseActionKind.Update,
                    Brushes.StatusWarning));
            }
            else if (LifecycleState == PluginLifecycleState.Deactivating)
            {
                ActionItems.Add(LicenseActionItem.Primary(
                    "Reactivate License",
                    LicenseActionKind.RetryInstallation,
                    Brushes.StatusInfo));
            }
            else if (IsPluginMissing)
            {
                ActionItems.Add(LicenseActionItem.Primary(
                    "Reinstall Plugin",
                    LicenseActionKind.RetryInstallation,
                    Brushes.StatusInfo));
            }

            if (LifecycleState == PluginLifecycleState.Deactivating || IsRevoked)
            {
                ActionItems.Add(LicenseActionItem.Secondary("Remove Key", LicenseActionKind.RemoveKey));
            }
            else
            {
                ActionItems.Add(LicenseActionItem.Secondary("Deactivate License", LicenseActionKind.Deactivate));
            }

            if (HasInstalledPlugin)
            {
                ActionItems.Add(LicenseActionItem.Secondary("Remove Plugin", LicenseActionKind.RemovePlugin));
            }

            OnPropertyChanged(nameof(ActionItemsVisibility));
        }

        private void ResetSteps()
        {
            InstallationSteps.Clear();
            InstallationSteps.Add(new InstallationStepViewModel("Validating license", InstallationStepKind.Validation));
            InstallationSteps.Add(new InstallationStepViewModel("Downloading release", InstallationStepKind.Download));
            InstallationSteps.Add(new InstallationStepViewModel("Installing plugin", InstallationStepKind.Install));
            InstallationSteps.Add(new InstallationStepViewModel("Activating license on this machine", InstallationStepKind.Activation));
        }

        private void ClearStaleFeedbackForHealthyState()
        {
            if (InstallationFailed)
            {
                return;
            }

            if (LifecycleState is not (PluginLifecycleState.Active or PluginLifecycleState.UpdateAvailable))
            {
                return;
            }

            if (ReferenceEquals(FeedbackBrush, Brushes.StatusError) ||
                ReferenceEquals(FeedbackBrush, Brushes.StatusWarning))
            {
                ClearWarningOrErrorFeedback();
            }
        }

        private void OnStatusChanged()
        {
            OnPropertyChanged(nameof(StatusTitle));
            OnPropertyChanged(nameof(StatusMessage));
            OnPropertyChanged(nameof(StatusIcon));
            OnPropertyChanged(nameof(StatusBrush));
            OnPropertyChanged(nameof(StatusBadgeBackground));
            OnPropertyChanged(nameof(ActivationsVisibility));
            OnPropertyChanged(nameof(InstallationProgressVisibility));
            OnPropertyChanged(nameof(InstallationTargetVisibility));
            OnPropertyChanged(nameof(InstallationTargetText));
            OnPropertyChanged(nameof(DetailsVisibility));
            OnPropertyChanged(nameof(DeactivationDateVisibility));
            OnPropertyChanged(nameof(PreviousVersionsSectionVisibility));
            OnPropertyChanged(nameof(FilteredPreviousVersions));
            OnPropertyChanged(nameof(InstallationFailedActionsVisibility));
            OnPropertyChanged(nameof(SuspendedActionsVisibility));
            OnPropertyChanged(nameof(MainActionsVisibility));
            OnPropertyChanged(nameof(PrimaryActionText));
            OnPropertyChanged(nameof(PrimaryActionBrush));
            OnPropertyChanged(nameof(PrimaryActionVisibility));
            OnPropertyChanged(nameof(SecondaryActionText));
            OnPropertyChanged(nameof(RemovePluginVisibility));
            OnPropertyChanged(nameof(HasInstalledPlugin));
            OnPropertyChanged(nameof(HasSavedLicense));
            OnPropertyChanged(nameof(IsLicenseRemovedOnThisMachine));
            OnPropertyChanged(nameof(IsPluginRemoved));
            OnPropertyChanged(nameof(IsPluginMissing));
            OnPropertyChanged(nameof(SecondaryBrush));
            OnPropertyChanged(nameof(SecondaryText));
            RebuildActionItems();
        }
    }
}
