using System;
using System.Windows.Media;

namespace MCAppsTools
{
    public sealed class ReleaseVersionInfo : NotifyObject
    {
        public ReleaseVersionInfo(string version, string channel, string releaseId)
        {
            Version = version;
            Channel = channel;
            ReleaseId = releaseId;
        }

        public string Version { get; }
        public string Channel { get; }
        public string ReleaseId { get; }
        public string VersionText => $"v{Version}";
        public Brush ChannelBrush => Channel.Equals("beta", StringComparison.OrdinalIgnoreCase) ? Brushes.StatusWarning : Brushes.StatusActive;
    }
}
