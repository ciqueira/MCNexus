using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace MCAppsTools
{
    public sealed class SessionTokenStore
    {
        private static readonly TimeSpan StaleCacheAge = TimeSpan.FromHours(24);
        private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

        private readonly TimeSpan _renewalSafetyBuffer;
        private readonly Dictionary<string, SessionTokenEntry> _tokensByKey = new(StringComparer.OrdinalIgnoreCase);
        private readonly AppPaths? _paths;
        private readonly SecureDataProtector? _protector;

        public SessionTokenStore()
            : this(TimeSpan.FromSeconds(60))
        {
        }

        public SessionTokenStore(TimeSpan renewalSafetyBuffer)
        {
            _renewalSafetyBuffer = renewalSafetyBuffer;
        }

        public SessionTokenStore(AppPaths paths, string machineFingerprint)
            : this(TimeSpan.FromSeconds(60), paths, machineFingerprint)
        {
        }

        public SessionTokenStore(TimeSpan renewalSafetyBuffer, AppPaths paths, string machineFingerprint)
        {
            _renewalSafetyBuffer = renewalSafetyBuffer;
            _paths = paths;
            _protector = new SecureDataProtector(machineFingerprint);
        }

        public void Store(string token, int expiresIn, string licenseKey)
        {
            if (string.IsNullOrWhiteSpace(token) || string.IsNullOrWhiteSpace(licenseKey))
            {
                return;
            }

            CleanupStaleCacheFiles();

            var entry = new SessionTokenEntry
            {
                Token = token,
                ExpiresAt = DateTimeOffset.UtcNow.AddSeconds(expiresIn)
            };
            _tokensByKey[licenseKey] = entry;
            WriteToLocalStorage(entry, licenseKey);
        }

        public string? TokenFor(string licenseKey)
        {
            CleanupStaleCacheFiles();

            if (!_tokensByKey.TryGetValue(licenseKey, out var entry))
            {
                entry = ReadFromLocalStorage(licenseKey);
                if (entry is null)
                {
                    return null;
                }
            }

            if (entry.ExpiresAt <= DateTimeOffset.UtcNow.Add(_renewalSafetyBuffer))
            {
                _tokensByKey.Remove(licenseKey);
                DeleteFromLocalStorage(licenseKey);
                return null;
            }

            _tokensByKey[licenseKey] = entry;
            return entry.Token;
        }

        public void Clear(string licenseKey)
        {
            _tokensByKey.Remove(licenseKey);
            DeleteFromLocalStorage(licenseKey);
        }

        private void WriteToLocalStorage(SessionTokenEntry entry, string licenseKey)
        {
            if (_paths is null || _protector is null)
            {
                return;
            }

            try
            {
                _paths.EnsureDirectories();
                var json = JsonSerializer.Serialize(entry, JsonOptions);
                File.WriteAllBytes(TokenPath(licenseKey), _protector.ProtectString(json));
            }
            catch
            {
                // Token persistence is a convenience cache. Network fallback can renew it.
            }
        }

        private SessionTokenEntry? ReadFromLocalStorage(string licenseKey)
        {
            if (_protector is null)
            {
                return null;
            }

            var path = TokenPath(licenseKey);
            if (!File.Exists(path))
            {
                return null;
            }

            try
            {
                var json = _protector.UnprotectString(File.ReadAllBytes(path));
                return JsonSerializer.Deserialize<SessionTokenEntry>(json, JsonOptions);
            }
            catch
            {
                DeleteFromLocalStorage(licenseKey);
                return null;
            }
        }

        private void DeleteFromLocalStorage(string licenseKey)
        {
            var path = TokenPath(licenseKey);
            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch
            {
                // Best-effort cache cleanup.
            }
        }

        private void CleanupStaleCacheFiles()
        {
            if (_paths is null)
            {
                return;
            }

            try
            {
                _paths.EnsureDirectories();
                var cutoff = DateTimeOffset.UtcNow.Subtract(StaleCacheAge);
                foreach (var file in Directory.EnumerateFiles(_paths.CacheDirectory, "*.cache"))
                {
                    var modifiedAt = File.GetLastWriteTimeUtc(file);
                    if (modifiedAt < cutoff.UtcDateTime)
                    {
                        File.Delete(file);
                    }
                }
            }
            catch
            {
                // Best-effort cache maintenance.
            }
        }

        private string TokenPath(string licenseKey)
        {
            return _paths is null
                ? string.Empty
                : Path.Combine(_paths.CacheDirectory, $"{TokenFileName(licenseKey)}.cache");
        }

        private static string TokenFileName(string licenseKey)
        {
            var hash = SHA256.HashData(Encoding.UTF8.GetBytes(licenseKey.Trim().ToUpperInvariant()));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private sealed class SessionTokenEntry
        {
            public string Token { get; set; } = string.Empty;
            public DateTimeOffset ExpiresAt { get; set; }
        }
    }
}
