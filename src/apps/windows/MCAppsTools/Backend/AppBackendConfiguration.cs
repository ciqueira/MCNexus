using System;
using System.IO;

namespace MCAppsTools
{
    public static class AppBackendConfiguration
    {
        public static AppEnvironment Environment => AppEnvironment.Current;
        public static string BaseUrl => Environment.BaseUrl;
        public static Uri BaseUri => Environment.BaseUri;
        public static string AppVersion { get; } = LoadAppVersion();

        private static string LoadAppVersion()
        {
            var versionPath = Path.Combine(AppContext.BaseDirectory, "VERSION");
            if (!File.Exists(versionPath))
            {
                return "unknown";
            }

            var version = File.ReadAllText(versionPath).Trim();
            return string.IsNullOrWhiteSpace(version) ? "unknown" : version;
        }
    }
}
