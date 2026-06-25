using System.Windows;
using System.Windows.Media;

namespace MCAppsTools
{
    internal static class Brushes
    {
        public static readonly Brush PanelSurface = ResourceBrush("PanelSurfaceBrush");
        public static readonly Brush PanelSelected = ResourceBrush("PanelSelectedBrush");
        public static readonly Brush TextPrimary = ResourceBrush("TextPrimaryBrush");
        public static readonly Brush TextStrong = ResourceBrush("TextStrongBrush");
        public static readonly Brush TextSecondary = ResourceBrush("TextSecondaryBrush");
        public static readonly Brush TextMuted = ResourceBrush("TextMutedBrush");
        public static readonly Brush TextFaint = ResourceBrush("TextFaintBrush");
        public static readonly Brush BorderSubtle = ResourceBrush("BorderSubtleBrush");
        public static readonly Brush StatusActive = ResourceBrush("StatusActiveBrush");
        public static readonly Brush StatusInfo = ResourceBrush("StatusInfoBrush");
        public static readonly Brush StatusWarning = ResourceBrush("StatusWarningBrush");
        public static readonly Brush StatusError = ResourceBrush("StatusErrorBrush");
        public static readonly Brush StatusIdle = ResourceBrush("StatusIdleBrush");
        public static readonly Brush Transparent = new SolidColorBrush(Colors.Transparent);

        public static Brush WithOpacity(Brush brush, byte alpha)
        {
            if (brush is SolidColorBrush solid)
            {
                return new SolidColorBrush(Color.FromArgb(alpha, solid.Color.R, solid.Color.G, solid.Color.B));
            }

            return brush;
        }

        private static Brush ResourceBrush(string key)
        {
            return (Brush)Application.Current.Resources[key];
        }
    }
}
