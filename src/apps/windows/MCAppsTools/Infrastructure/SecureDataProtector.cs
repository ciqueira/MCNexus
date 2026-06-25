using System.Security.Cryptography;
using System.Text;

namespace MCAppsTools
{
    public sealed class SecureDataProtector
    {
        private readonly byte[] _entropy;

        public SecureDataProtector(string machineFingerprint)
        {
            _entropy = Encoding.UTF8.GetBytes($"MCAppsTools.Windows.{machineFingerprint}");
        }

        public byte[] ProtectString(string value)
        {
            var plainBytes = Encoding.UTF8.GetBytes(value);
            return ProtectedData.Protect(plainBytes, _entropy, DataProtectionScope.CurrentUser);
        }

        public string UnprotectString(byte[] protectedBytes)
        {
            var plainBytes = ProtectedData.Unprotect(protectedBytes, _entropy, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plainBytes);
        }
    }
}
