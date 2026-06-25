using System;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;

namespace MCAppsTools
{
    public static class LicenseKeyIdentity
    {
        private static readonly Regex SignedKeyRegex = new(
            "^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{8}$",
            RegexOptions.Compiled);

        public static string Normalize(string key)
        {
            return key.Trim().ToUpperInvariant();
        }

        public static bool IsSignedKey(string key)
        {
            return SignedKeyRegex.IsMatch(key.Trim());
        }

        public static string Hash(string normalizedKey)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(normalizedKey));
            return Convert.ToHexString(bytes);
        }

        public static string DisplayText(string value)
        {
            var normalized = Normalize(value);
            if (!IsSignedKey(normalized))
            {
                return string.IsNullOrWhiteSpace(value) ? "Key not retained" : value;
            }

            return $"Key ending {normalized[^6..]}";
        }
    }
}
