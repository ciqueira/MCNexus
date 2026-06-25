using System;
using System.IO;

namespace MCAppsTools
{
    public sealed class AppPaths
    {
        public AppPaths()
            : this(System.Environment.GetFolderPath(System.Environment.SpecialFolder.ApplicationData))
        {
        }

        public AppPaths(string appDataRoot)
            : this(appDataRoot, AppEnvironment.Current)
        {
        }

        public AppPaths(string appDataRoot, AppEnvironment environment)
        {
            Environment = environment;
            RootDirectory = environment.GetApplicationDataDirectory(appDataRoot);
            StateDirectory = Path.Combine(RootDirectory, "State");
            RecordsDirectory = Path.Combine(StateDirectory, "Records");
            CacheDirectory = Path.Combine(StateDirectory, "Cache");
            ProductCredentialsDirectory = Path.Combine(RootDirectory, "ProductCredentials");
            LicenseMetadataPath = Path.Combine(StateDirectory, "licenses.json");
        }

        public AppEnvironment Environment { get; }
        public string RootDirectory { get; }
        public string StateDirectory { get; }
        public string RecordsDirectory { get; }
        public string CacheDirectory { get; }
        public string ProductCredentialsDirectory { get; }
        public string LicenseMetadataPath { get; }

        public void EnsureDirectories()
        {
            Directory.CreateDirectory(RootDirectory);
            Directory.CreateDirectory(StateDirectory);
            Directory.CreateDirectory(RecordsDirectory);
            Directory.CreateDirectory(CacheDirectory);
            Directory.CreateDirectory(ProductCredentialsDirectory);
        }
    }
}
