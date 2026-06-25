using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Threading.Tasks;

namespace MCAppsTools
{
    public sealed class InstallTransaction
    {
        internal InstallTransaction(string backupRoot)
        {
            BackupRoot = backupRoot;
            InstalledBundleNames = new List<string>();
            BundleBackups = new List<BundleInstallBackup>();
        }

        public List<string> InstalledBundleNames { get; }

        internal string BackupRoot { get; }
        internal List<BundleInstallBackup> BundleBackups { get; }
        internal bool IsCompleted { get; set; }
    }

    internal sealed class BundleInstallBackup
    {
        public required string BundleName { get; init; }
        public required string TargetPath { get; init; }
        public string? BackupPath { get; init; }
    }

    public sealed class InstallService
    {
        private const string TargetPluginDirectory = @"C:\Program Files\Common Files\OFX\Plugins";
        private const string OfxBundleExtension = ".ofx.bundle";
        private const string BackupDirectoryName = ".mcnexus-install-backups";
        private const string BackupInstallDirectoryPrefix = "install-";
        private readonly AppEnvironment _environment;

        public InstallService()
            : this(AppEnvironment.Current)
        {
        }

        public InstallService(AppEnvironment environment)
        {
            _environment = environment;
        }

        public async Task<System.Collections.Generic.List<string>> ExtractAndInstallAsync(string zipFilePath)
        {
            var transaction = await ExtractAndInstallTransactionalAsync(zipFilePath);
            CommitInstallTransaction(transaction);
            return transaction.InstalledBundleNames;
        }

        public async Task<InstallTransaction> ExtractAndInstallTransactionalAsync(string zipFilePath)
        {
            return await Task.Run(() =>
            {
                var extractRoot = Path.Combine(Path.GetTempPath(), "MCAppsTools", $"release-{Guid.NewGuid():N}");
                var backupRoot = Path.Combine(TargetPluginDirectory, BackupDirectoryName, $"{BackupInstallDirectoryPrefix}{Guid.NewGuid():N}");
                var transaction = new InstallTransaction(backupRoot);
                try
                {
                    if (!File.Exists(zipFilePath))
                    {
                        throw new FileNotFoundException($"Source zip file not found: {zipFilePath}");
                    }

                    if (!Directory.Exists(TargetPluginDirectory))
                    {
                        Directory.CreateDirectory(TargetPluginDirectory);
                    }

                    CleanupInstallBackups();
                    Directory.CreateDirectory(extractRoot);
                    Directory.CreateDirectory(backupRoot);
                    var safeExtractRoot = EnsureTrailingSeparator(Path.GetFullPath(extractRoot));

                    using (var archive = ZipFile.OpenRead(zipFilePath))
                    {
                        foreach (var entry in archive.Entries)
                        {
                            var destinationPath = Path.GetFullPath(Path.Combine(extractRoot, entry.FullName));
                            if (!destinationPath.StartsWith(safeExtractRoot, StringComparison.OrdinalIgnoreCase))
                            {
                                throw new InvalidDataException("Entry is outside of target directory (possible Zip Slip attack).");
                            }

                            if (string.IsNullOrEmpty(entry.Name))
                            {
                                // Directory entry
                                Directory.CreateDirectory(destinationPath);
                            }
                            else
                            {
                                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
                                entry.ExtractToFile(destinationPath, overwrite: true);
                            }
                        }
                    }

                    foreach (var bundleDirectory in Directory.EnumerateDirectories(extractRoot, "*.ofx.bundle", SearchOption.AllDirectories))
                    {
                        var attributes = File.GetAttributes(bundleDirectory);
                        if ((attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint)
                        {
                            continue;
                        }

                        var sourceBundleName = Path.GetFileName(bundleDirectory);
                        ValidateBundleName(sourceBundleName);

                        var bundleName = ApplyEnvironmentBundleSuffix(sourceBundleName);
                        ValidateBundleName(bundleName);

                        var targetPath = Path.GetFullPath(Path.Combine(TargetPluginDirectory, bundleName));
                        if (!IsInsideDirectory(targetPath, TargetPluginDirectory))
                        {
                            throw new InvalidDataException("Resolved bundle destination is outside of the OFX plugin directory.");
                        }

                        string? backupPath = null;
                        if (Directory.Exists(targetPath))
                        {
                            backupPath = Path.Combine(backupRoot, $"{bundleName}.bak");
                            if (Directory.Exists(backupPath))
                            {
                                Directory.Delete(backupPath, recursive: true);
                            }

                            Directory.Move(targetPath, backupPath);
                        }

                        transaction.BundleBackups.Add(new BundleInstallBackup
                        {
                            BundleName = bundleName,
                            TargetPath = targetPath,
                            BackupPath = backupPath
                        });

                        CopyDirectory(bundleDirectory, targetPath);
                        transaction.InstalledBundleNames.Add(bundleName);
                    }

                    if (transaction.InstalledBundleNames.Count == 0)
                    {
                        throw new InvalidDataException("No .ofx.bundle directory found in the release package.");
                    }

                    return transaction;
                }
                catch (Exception ex)
                {
                    try
                    {
                        RollbackInstallTransaction(transaction);
                    }
                    catch (Exception rollbackError)
                    {
                        throw new InvalidOperationException($"Installation failed: {ex.Message}. Could not restore previous plugin files: {rollbackError.Message}", ex);
                    }

                    throw new InvalidOperationException($"Installation failed: {ex.Message}", ex);
                }
                finally
                {
                    try
                    {
                        if (Directory.Exists(extractRoot))
                        {
                            Directory.Delete(extractRoot, recursive: true);
                        }
                    }
                    catch
                    {
                        // Temporary cleanup is best effort.
                    }
                }
            });
        }

        public void CommitInstallTransaction(InstallTransaction? transaction)
        {
            if (transaction == null || transaction.IsCompleted)
            {
                return;
            }

            try
            {
                if (Directory.Exists(transaction.BackupRoot))
                {
                    Directory.Delete(transaction.BackupRoot, recursive: true);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to cleanup install backup: {ex.Message}");
            }
            finally
            {
                CleanupInstallBackups();
                transaction.IsCompleted = true;
            }
        }

        public void RollbackInstallTransaction(InstallTransaction? transaction)
        {
            if (transaction == null || transaction.IsCompleted)
            {
                return;
            }

            foreach (var backup in transaction.BundleBackups.AsEnumerable().Reverse())
            {
                if (Directory.Exists(backup.TargetPath))
                {
                    Directory.Delete(backup.TargetPath, recursive: true);
                }
                else if (File.Exists(backup.TargetPath))
                {
                    File.Delete(backup.TargetPath);
                }

                if (!string.IsNullOrWhiteSpace(backup.BackupPath) && Directory.Exists(backup.BackupPath))
                {
                    Directory.Move(backup.BackupPath, backup.TargetPath);
                }
            }

            if (Directory.Exists(transaction.BackupRoot))
            {
                Directory.Delete(transaction.BackupRoot, recursive: true);
            }

            CleanupInstallBackups();

            transaction.IsCompleted = true;
        }

        public void UninstallBundles(System.Collections.Generic.IEnumerable<string> bundleNames)
        {
            foreach (var name in bundleNames)
            {
                if (string.IsNullOrWhiteSpace(name)) continue;

                var targetPath = Path.GetFullPath(Path.Combine(TargetPluginDirectory, name));
                if (!IsInsideDirectory(targetPath, TargetPluginDirectory))
                {
                    continue;
                }

                try
                {
                    if (Directory.Exists(targetPath))
                    {
                        Directory.Delete(targetPath, recursive: true);
                    }
                    else if (File.Exists(targetPath))
                    {
                        File.Delete(targetPath);
                    }
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Failed to uninstall {name}: {ex.Message}");
                }
            }
        }

        private static void ValidateBundleName(string bundleName)
        {
            if (string.IsNullOrWhiteSpace(bundleName) ||
                bundleName is "." or ".." ||
                bundleName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                !bundleName.EndsWith(OfxBundleExtension, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidDataException("Invalid OFX bundle name in release package.");
            }
        }

        private string ApplyEnvironmentBundleSuffix(string bundleName)
        {
            if (string.IsNullOrWhiteSpace(_environment.InstalledBundleNameSuffix))
            {
                return bundleName;
            }

            var baseName = bundleName.EndsWith(OfxBundleExtension, StringComparison.OrdinalIgnoreCase)
                ? bundleName[..^OfxBundleExtension.Length]
                : bundleName;

            return $"{baseName}-{_environment.InstalledBundleNameSuffix}{OfxBundleExtension}";
        }

        private static void CopyDirectory(string sourceDirectory, string targetDirectory)
        {
            Directory.CreateDirectory(targetDirectory);

            foreach (var directory in Directory.EnumerateDirectories(sourceDirectory, "*", SearchOption.AllDirectories))
            {
                var attributes = File.GetAttributes(directory);
                if ((attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint)
                {
                    continue;
                }

                var relativePath = Path.GetRelativePath(sourceDirectory, directory);
                Directory.CreateDirectory(Path.Combine(targetDirectory, relativePath));
            }

            foreach (var file in Directory.EnumerateFiles(sourceDirectory, "*", SearchOption.AllDirectories))
            {
                var attributes = File.GetAttributes(file);
                if ((attributes & FileAttributes.ReparsePoint) == FileAttributes.ReparsePoint)
                {
                    continue;
                }

                var relativePath = Path.GetRelativePath(sourceDirectory, file);
                var destinationPath = Path.Combine(targetDirectory, relativePath);
                Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);
                File.Copy(file, destinationPath, overwrite: true);
                
                // Ensure the file does not retain read-only or other restricting attributes
                File.SetAttributes(destinationPath, FileAttributes.Normal);
            }

            // Ensure correct permissions on the installed bundle directory
            try
            {
                using var process = new System.Diagnostics.Process();
                process.StartInfo.FileName = "icacls";
                // Grant Read & Execute to Everyone (S-1-1-0) recursively
                process.StartInfo.Arguments = $"\"{targetDirectory}\" /grant \"*S-1-1-0\":(OI)(CI)RX /T /Q";
                process.StartInfo.UseShellExecute = false;
                process.StartInfo.CreateNoWindow = true;
                process.Start();
                process.WaitForExit();
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to set permissions: {ex.Message}");
            }
        }

        private static bool IsInsideDirectory(string path, string directory)
        {
            var safeDirectory = EnsureTrailingSeparator(Path.GetFullPath(directory));
            var fullPath = Path.GetFullPath(path);
            return fullPath.StartsWith(safeDirectory, StringComparison.OrdinalIgnoreCase);
        }

        private static void CleanupInstallBackups(string? activeBackupRoot = null)
        {
            var backupParent = Path.Combine(TargetPluginDirectory, BackupDirectoryName);
            if (!Directory.Exists(backupParent))
            {
                return;
            }

            var activeFullPath = string.IsNullOrWhiteSpace(activeBackupRoot)
                ? null
                : Path.GetFullPath(activeBackupRoot);

            foreach (var backupDirectory in Directory.EnumerateDirectories(backupParent, $"{BackupInstallDirectoryPrefix}*"))
            {
                try
                {
                    var backupFullPath = Path.GetFullPath(backupDirectory);
                    if (activeFullPath != null &&
                        string.Equals(backupFullPath, activeFullPath, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    Directory.Delete(backupDirectory, recursive: true);
                }
                catch (Exception ex)
                {
                    System.Diagnostics.Debug.WriteLine($"Failed to cleanup stale install backup: {ex.Message}");
                }
            }

            try
            {
                if (!Directory.EnumerateFileSystemEntries(backupParent).Any())
                {
                    Directory.Delete(backupParent, recursive: false);
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Failed to cleanup install backup root: {ex.Message}");
            }
        }

        private static string EnsureTrailingSeparator(string path)
        {
            return path.EndsWith(Path.DirectorySeparatorChar) || path.EndsWith(Path.AltDirectorySeparatorChar)
                ? path
                : path + Path.DirectorySeparatorChar;
        }
    }
}
