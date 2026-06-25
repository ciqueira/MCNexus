using System;

namespace MCAppsTools
{
    public sealed class AppBackendEndpointConfig
    {
        private AppBackendEndpointConfig(TimeSpan timeout, int maxAttempts, TimeSpan initialBackoff)
        {
            Timeout = timeout;
            MaxAttempts = maxAttempts;
            InitialBackoff = initialBackoff;
        }

        public TimeSpan Timeout { get; }
        public int MaxAttempts { get; }
        public TimeSpan InitialBackoff { get; }

        public static AppBackendEndpointConfig Validate { get; } = new(TimeSpan.FromSeconds(25), 2, TimeSpan.FromSeconds(1.5));
        public static AppBackendEndpointConfig Sync { get; } = new(TimeSpan.FromSeconds(15), 2, TimeSpan.FromSeconds(1));
        public static AppBackendEndpointConfig ResolveDownload { get; } = new(TimeSpan.FromSeconds(20), 2, TimeSpan.FromSeconds(1));
        public static AppBackendEndpointConfig Health { get; } = new(TimeSpan.FromSeconds(10), 1, TimeSpan.Zero);
        public static AppBackendEndpointConfig SyncBatch { get; } = new(TimeSpan.FromSeconds(25), 2, TimeSpan.FromSeconds(1.5));
        public static AppBackendEndpointConfig AppLatest { get; } = new(TimeSpan.FromSeconds(8), 1, TimeSpan.Zero);
    }
}
