using System;
using System.IO;
using System.Reflection;

namespace MCAppsTools
{
    public enum AppEnvironmentName
    {
        Local,
        Staging,
        Production
    }

    public sealed class AppEnvironment
    {
        private AppEnvironment(
            AppEnvironmentName name,
            string baseUrl,
            string applicationDataDirectoryName,
            string licensesStorageKey,
            string? installedBundleNameSuffix)
        {
            Name = name;
            BaseUrl = baseUrl;
            BaseUri = new Uri(baseUrl, UriKind.Absolute);
            ApplicationDataDirectoryName = applicationDataDirectoryName;
            LicensesStorageKey = licensesStorageKey;
            InstalledBundleNameSuffix = installedBundleNameSuffix;
        }

        public static AppEnvironment Current { get; } = ResolveCurrent();

        public AppEnvironmentName Name { get; }
        public string BaseUrl { get; }
        public Uri BaseUri { get; }
        public string ApplicationDataDirectoryName { get; }
        public string LicensesStorageKey { get; }
        public string? InstalledBundleNameSuffix { get; }

        public string GetApplicationDataDirectory(string appDataRoot)
        {
            return Path.Combine(appDataRoot, ApplicationDataDirectoryName);
        }

        private static AppEnvironment ResolveCurrent()
        {
#if DEBUG
            var requestedEnvironment = System.Environment
                .GetEnvironmentVariable("MCAPPSTOOLS_ENV")?
                .Trim()
                .ToLowerInvariant();

            if (requestedEnvironment == "local")
            {
                return Local();
            }

            return Staging();
#else
            return Production();
#endif
        }

        private static AppEnvironment Local()
        {
            return new AppEnvironment(
                AppEnvironmentName.Local,
                RequiredAssemblyMetadataValue("MCNexusLocalBaseURL"),
                "MCAppsTools-Local",
                "com.mcappstools.local.activeLicenses",
                "local");
        }

        private static AppEnvironment Staging()
        {
            return new AppEnvironment(
                AppEnvironmentName.Staging,
                RequiredAssemblyMetadataValue("MCNexusStagingBaseURL"),
                "MCAppsTools-Staging",
                "com.mcappstools.staging.activeLicenses",
                "staging");
        }

        private static AppEnvironment Production()
        {
            return new AppEnvironment(
                AppEnvironmentName.Production,
                RequiredAssemblyMetadataValue("MCNexusProductionBaseURL"),
                "MCAppsTools",
                "com.mcappstools.activeLicenses",
                null);
        }

        private static string RequiredAssemblyMetadataValue(string key)
        {
            foreach (var attribute in Assembly.GetExecutingAssembly().GetCustomAttributes<AssemblyMetadataAttribute>())
            {
                if (!string.Equals(attribute.Key, key, StringComparison.Ordinal))
                {
                    continue;
                }

                var value = attribute.Value?.Trim() ?? string.Empty;
                if (!string.IsNullOrWhiteSpace(value) &&
                    !value.StartsWith("$(", StringComparison.Ordinal) &&
                    Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
                    !string.IsNullOrWhiteSpace(uri.Scheme))
                {
                    return value;
                }
            }

            throw new InvalidOperationException($"Missing required assembly metadata value: {key}");
        }
    }
}
