using System.Windows.Media;

namespace MCAppsTools
{
    public sealed class LicenseActionItem
    {
        private LicenseActionItem(
            string text,
            LicenseActionKind kind,
            Brush background,
            Brush borderBrush,
            Brush foreground)
        {
            Text = text;
            Kind = kind;
            Background = background;
            BorderBrush = borderBrush;
            Foreground = foreground;
        }

        public string Text { get; }
        public LicenseActionKind Kind { get; }
        public Brush Background { get; }
        public Brush BorderBrush { get; }
        public Brush Foreground { get; }

        public static LicenseActionItem Primary(string text, LicenseActionKind kind, Brush background)
        {
            return new LicenseActionItem(text, kind, background, Brushes.Transparent, Brushes.TextPrimary);
        }

        public static LicenseActionItem Secondary(string text, LicenseActionKind kind)
        {
            return new LicenseActionItem(text, kind, Brushes.Transparent, Brushes.BorderSubtle, Brushes.TextStrong);
        }
    }
}
