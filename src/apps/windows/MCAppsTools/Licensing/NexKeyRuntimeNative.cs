using System;
using System.Runtime.InteropServices;
using System.Text;

namespace MCAppsTools
{
    /// <summary>
    /// Mirrors <c>NexKeyRuntimeResult</c> in <c>nexkeyruntime.h</c>. Values
    /// and gaps (11-19) are intentional — licensing codes were appended
    /// starting at 20 without renumbering the update-handle codes that
    /// shipped first; kept identical here so this enum can never drift from
    /// the ABI it wraps.
    /// </summary>
    internal enum NexKeyRuntimeResult
    {
        Ok = 0,
        InvalidArgument = 1,
        InvalidConfig = 2,
        Busy = 3,
        NetworkError = 4,
        HttpError = 5,
        InvalidManifest = 6,
        UnsupportedSchema = 7,
        NotAvailable = 8,
        BufferTooSmall = 9,
        InternalError = 10,

        ProductData = 20,
        ProductDataExpired = 21,
        AbiMismatch = 22,

        LicenseKey = 30,
        ActivationLimit = 31,
        LicenseExpired = 32,
        LicenseSuspended = 33,
        LicenseRevoked = 34,
        ProductActivated = 35,
        WrongTenant = 36,
        ActivationNotFound = 37,

        NoReceipt = 40,
        Signature = 41,
        DeviceMismatch = 42,
        Entitlement = 43,
        Clock = 44,

        Storage = 50
    }

    /// <summary>Mirrors <c>NexKeyRuntimeLicenseStatus</c> in <c>nexkeyruntime.h</c>.</summary>
    internal enum NexKeyRuntimeLicenseStatus
    {
        Unknown = 0,
        NotActivated,
        Activating,
        Active,
        OfflineGrace,
        OfflineGraceExpired,
        Expired,
        Suspended,
        Revoked,
        ActivationRemoved,
        DeviceMismatch,
        CertificateInvalid,
        ClockRollback,
        ServiceUnavailable,
        InternalError
    }

    internal enum NexKeyRuntimeRenderDecision
    {
        Deny = 0,
        Allow = 1
    }

    /// <summary>
    /// Invoked on the SDK's own poller thread, never on the caller's thread
    /// — the ABI's contract is that it must not block and must not call
    /// back into the handle. Kept as an instance field wherever it is
    /// passed to <c>set_callback</c> (never a local/inline lambda), so the
    /// GC cannot collect it while the native side still holds the pointer.
    /// </summary>
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    internal delegate void NexKeyRuntimeLicenseCallback(NexKeyRuntimeLicenseStatus status, IntPtr userData);

    /// <summary>
    /// Mirrors <c>NexKeyRuntimeLicenseSnapshot</c> field-for-field. The
    /// three fixed buffers are UTF-8, NUL-terminated, and sized exactly as
    /// the C struct declares them (<c>NEXKEYRUNTIME_VERSION_CAPACITY</c> /
    /// <c>NEXKEYRUNTIME_ID_CAPACITY</c>) — changing either without changing
    /// the other desyncs this struct's layout from the DLL's.
    /// </summary>
    [StructLayout(LayoutKind.Sequential)]
    internal struct NexKeyRuntimeLicenseSnapshot
    {
        private const int VersionCapacity = 64;
        private const int IdCapacity = 160;

        public UIntPtr struct_size;
        public NexKeyRuntimeLicenseStatus status;
        public NexKeyRuntimeRenderDecision decision;
        public NexKeyRuntimeResult last_error;

        public long activated_at;

        public long expires_at;
        public int days_remaining;

        public long sync_after;
        public long offline_valid_until;
        public long last_synced_at;

        public int activations_used;
        public int max_activations;

        [MarshalAs(UnmanagedType.ByValArray, SizeConst = VersionCapacity)]
        public byte[] edition;
        public int edition_enum;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = IdCapacity)]
        public byte[] activation_id;
        [MarshalAs(UnmanagedType.ByValArray, SizeConst = IdCapacity)]
        public byte[] certificate_id;

        /// <summary>
        /// A zeroed snapshot with <c>struct_size</c> pre-filled — the ABI's
        /// own versioning check, and the fixed buffers pre-allocated so the
        /// marshaler has somewhere to copy into on the way back from
        /// <c>get_snapshot</c>.
        /// </summary>
        public static NexKeyRuntimeLicenseSnapshot Create()
        {
            return new NexKeyRuntimeLicenseSnapshot
            {
                struct_size = (UIntPtr)Marshal.SizeOf<NexKeyRuntimeLicenseSnapshot>(),
                edition = new byte[VersionCapacity],
                activation_id = new byte[IdCapacity],
                certificate_id = new byte[IdCapacity]
            };
        }

        public readonly string EditionText => DecodeUtf8Z(edition);
        public readonly string ActivationId => DecodeUtf8Z(activation_id);
        public readonly string CertificateId => DecodeUtf8Z(certificate_id);

        private static string DecodeUtf8Z(byte[] buffer)
        {
            var length = Array.IndexOf(buffer, (byte)0);
            if (length < 0)
            {
                length = buffer.Length;
            }

            return Encoding.UTF8.GetString(buffer, 0, length);
        }
    }

    /// <summary>
    /// P/Invoke surface over <c>nexkeyruntime.h</c>'s licensing block
    /// (Bloco A/B/C). Only the subset <see cref="NexKeyRuntimeProvider"/>
    /// actually calls — this is not a full binding of the header.
    /// </summary>
    internal static class NexKeyRuntimeNative
    {
        private const string DllName = "nexkeyruntime";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern IntPtr nexkeyruntime_license_create();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern void nexkeyruntime_license_destroy(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_product_data(
            IntPtr handle,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string productData);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_tenant_id(
            IntPtr handle,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string tenantId);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_variant(
            IntPtr handle,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string variant);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_license_key(
            IntPtr handle,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string key);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_metadata(
            IntPtr handle,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string key,
            [MarshalAs(UnmanagedType.LPUTF8Str)] string value);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_set_callback(
            IntPtr handle,
            NexKeyRuntimeLicenseCallback callback,
            IntPtr userData);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_activate(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_deactivate(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_load_local(IntPtr handle);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_get_snapshot(
            IntPtr handle,
            ref NexKeyRuntimeLicenseSnapshot snapshot);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        internal static extern NexKeyRuntimeResult nexkeyruntime_license_request_sync(IntPtr handle, int force);
    }
}
