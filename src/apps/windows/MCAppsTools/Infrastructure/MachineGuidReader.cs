using Microsoft.Win32;

namespace MCAppsTools
{
    /// <summary>
    /// Reads the SAME hardware identifier NexKeyRuntime's own
    /// <c>hardware_id_windows.cpp</c> reads — never
    /// <see cref="MachineFingerprintService"/> (WMI SMBIOS UUID, the legacy
    /// Cryptlex identity; a completely different value on Windows, see
    /// PLANO_CONSOLIDADO.md §"BLOQUEANTE NOVO", Fase 5).
    ///
    /// Used only for: (1) the <c>hardwareId</c> field of
    /// <c>POST /v1/licenses/migrate-binding</c>, so the backend can
    /// pre-compute the binding the SDK's own activation will independently
    /// produce; and (2) <c>NexKeyRuntimeProvider.MachineFingerprint()</c>.
    ///
    /// Must match <c>hardware_id_windows.cpp</c> byte for byte:
    /// <c>HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography</c>, value
    /// <c>MachineGuid</c>, opened against the 64-bit registry view
    /// explicitly (so a 32-bit build reads the same value a 64-bit build
    /// would, never the WOW64-redirected copy), returned RAW — no case
    /// normalization. Diverging in either of those silently breaks
    /// migrate-binding: it would pre-compute a binding the SDK never
    /// actually produces, and the migration would "succeed" while a second
    /// activation row appears anyway.
    /// </summary>
    public static class MachineGuidReader
    {
        public static string Generate()
        {
            try
            {
                using var baseKey = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64);
                using var key = baseKey.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
                return key?.GetValue("MachineGuid") as string ?? string.Empty;
            }
            catch
            {
                return string.Empty;
            }
        }
    }
}
