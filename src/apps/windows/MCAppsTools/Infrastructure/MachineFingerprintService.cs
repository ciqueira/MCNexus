using System;
using System.Management;

namespace MCAppsTools
{
    public static class MachineFingerprintService
    {
        public static string Generate()
        {
            try
            {
                using var searcher = new ManagementObjectSearcher("SELECT UUID FROM Win32_ComputerSystemProduct");
                foreach (var obj in searcher.Get())
                {
                    var uuid = obj["UUID"]?.ToString();
                    if (!string.IsNullOrWhiteSpace(uuid) &&
                        !uuid.Equals("FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", StringComparison.OrdinalIgnoreCase))
                    {
                        return uuid.ToUpperInvariant();
                    }
                }
            }
            catch
            {
                // WMI can be unavailable in VMs or design-time contexts.
            }

            return string.Empty;
        }
    }
}
