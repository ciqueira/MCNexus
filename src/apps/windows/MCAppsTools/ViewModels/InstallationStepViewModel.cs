using System.Windows;
using System.Windows.Media;

namespace MCAppsTools
{
    public sealed class InstallationStepViewModel : NotifyObject
    {
        private InstallationStepStatus _status;
        private double _progressValue;
        private string _progressText = string.Empty;
        private string _errorDetail = string.Empty;

        public InstallationStepViewModel(string label, InstallationStepKind kind)
        {
            Label = label;
            Kind = kind;
            Status = InstallationStepStatus.Pending;
        }

        public string Label { get; }
        public InstallationStepKind Kind { get; }

        public InstallationStepStatus Status
        {
            get => _status;
            set
            {
                if (SetProperty(ref _status, value))
                {
                    OnPropertyChanged(nameof(Icon));
                    OnPropertyChanged(nameof(IconBrush));
                    OnPropertyChanged(nameof(TextBrush));
                    OnPropertyChanged(nameof(DownloadVisibility));
                    OnPropertyChanged(nameof(InstallPathVisibility));
                    OnPropertyChanged(nameof(IsRunning));
                }
            }
        }

        public double ProgressValue
        {
            get => _progressValue;
            set => SetProperty(ref _progressValue, value);
        }

        public string ProgressText
        {
            get => _progressText;
            set => SetProperty(ref _progressText, value);
        }

        public string ErrorDetail
        {
            get => _errorDetail;
            set
            {
                if (SetProperty(ref _errorDetail, value))
                {
                    OnPropertyChanged(nameof(ErrorVisibility));
                }
            }
        }

        public string Icon => Status switch
        {
            InstallationStepStatus.Running => "\uE895",
            InstallationStepStatus.Completed => "\uE930",
            InstallationStepStatus.Failed => "\uE711",
            _ => "\uE91F"
        };

        public Brush IconBrush => Status switch
        {
            InstallationStepStatus.Running => Brushes.StatusInfo,
            InstallationStepStatus.Completed => Brushes.StatusActive,
            InstallationStepStatus.Failed => Brushes.StatusError,
            _ => Brushes.TextFaint
        };

        public Brush TextBrush => Status switch
        {
            InstallationStepStatus.Running => Brushes.TextStrong,
            InstallationStepStatus.Completed => Brushes.TextMuted,
            InstallationStepStatus.Failed => Brushes.TextStrong,
            _ => Brushes.TextFaint
        };

        public bool IsRunning => Status == InstallationStepStatus.Running;

        public Visibility DownloadVisibility => Kind == InstallationStepKind.Download && Status == InstallationStepStatus.Running ? Visibility.Visible : Visibility.Collapsed;
        public Visibility InstallPathVisibility => Kind == InstallationStepKind.Install ? Visibility.Visible : Visibility.Collapsed;
        public Visibility ErrorVisibility => string.IsNullOrWhiteSpace(ErrorDetail) ? Visibility.Collapsed : Visibility.Visible;
    }
}
