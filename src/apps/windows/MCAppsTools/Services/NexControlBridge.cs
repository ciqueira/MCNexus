using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace MCAppsTools.Services
{
    public enum NexControlHubStatus
    {
        Stopped,
        Running,
        DllNotFound,
        BadImageFormat,
        EntryPointNotFound,
        StartFailed
    }

    [InlineArray(64)]
    internal struct FixedUtf8Buffer64
    {
        private byte _element0;
    }

    public struct NexControlDeviceInfo
    {
        public uint StructSize;
        public string PortId;
        public string DisplayName;
        public string ProfileModel;
        public byte ProfileTier;
        public byte IsEnabled;
        public byte ConnectionState;
    }

    public struct NexControlTelemetrySnapshot
    {
        public nuint StructSize;
        public ulong PacketsReceived;
        public ulong DeltasApplied;
        public double P99LatencyMs;
        public uint ActiveInstances;
        public byte MidiConnected;
        public string MidiDeviceName;
        public byte ClientConnected;
        public string ClientPluginName;
        public uint ActiveNodeId;
        public byte LastCc;
        public sbyte LastDelta;
        public ulong TotalTicks;
        public ulong LastActivityTimestampMs;
        public uint BankMapSeq;
        public ushort ActiveVbankIndex;
        public ushort TotalVbanks;
        public byte ActiveHwBank;
        public byte LastEncoderMode;
        public byte LastMidiChannel;
        public byte LastBank;
        public byte LastMatched;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8)]
    internal struct NexControlDeviceInfoNative
    {
        public uint StructSize;
        public FixedUtf8Buffer64 PortId;
        public FixedUtf8Buffer64 DisplayName;
        public FixedUtf8Buffer64 ProfileModel;
        public byte ProfileTier;
        public byte IsEnabled;
        public byte ConnectionState;
        private byte _res0;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8)]
    internal struct NexControlTelemetrySnapshotNative
    {
        public nuint StructSize;
        public ulong PacketsReceived;
        public ulong DeltasApplied;
        public double P99LatencyMs;
        public uint ActiveInstances;
        public byte MidiConnected;
        public FixedUtf8Buffer64 MidiDeviceName;
        public byte ClientConnected;
        public FixedUtf8Buffer64 ClientPluginName;
        public uint ActiveNodeId;
        public byte LastCc;
        public sbyte LastDelta;
        public ulong TotalTicks;
        public ulong LastActivityTimestampMs;
        public uint BankMapSeq;
        public ushort ActiveVbankIndex;
        public ushort TotalVbanks;
        public byte ActiveHwBank;
        public byte LastEncoderMode;
        public byte LastMidiChannel;
        public byte LastBank;
        public byte LastMatched;
        private byte _res0;
        private byte _res1;
        private byte _res2;
    }

    public static class NexControlBridge
    {
        private const string DllName = "nexcontrol_hub";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        private static extern int nexcontrol_hub_start([MarshalAs(UnmanagedType.LPUTF8Str)] string? socketPath);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        private static extern int nexcontrol_hub_stop();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        private static extern int nexcontrol_hub_set_active_node(uint instanceId);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        private static extern int nexcontrol_hub_get_telemetry(ref NexControlTelemetrySnapshotNative outSnapshot);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        public static extern uint nexcontrol_hub_get_device_count();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        internal static extern int nexcontrol_hub_get_device_info(uint index, ref NexControlDeviceInfoNative outInfo);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        public static extern int nexcontrol_hub_set_port_enabled([MarshalAs(UnmanagedType.LPUTF8Str)] string portId, byte enabled);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        public static extern int nexcontrol_hub_set_generic_encoder_mode(byte encoderMode);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        [DefaultDllImportSearchPaths(DllImportSearchPath.ApplicationDirectory)]
        public static extern int nexcontrol_hub_reload_profiles([MarshalAs(UnmanagedType.LPUTF8Str)] string? customDirPath);

        private static bool _isRunning;
        private static NexControlHubStatus _status = NexControlHubStatus.Stopped;
        private static int _lastStartErrorCode;
        private static string? _midiDeviceName;
        private static uint _activeNodeId;
        private static CancellationTokenSource? _trackerCts;
        private static Task? _trackerTask;
        private static readonly object SyncLock = new();
        private static readonly object PortsConfigLock = new();
        private static readonly object SettingsConfigLock = new();

        private sealed class NexControlPortsConfig
        {
            public List<string> AllowedPorts { get; set; } = new();
        }

        private sealed class NexControlSettingsConfig
        {
            public byte? GenericEncoderMode { get; set; }
        }

        private static ulong _lastObservedTicks;
        private static ulong _lastObservedActivityMs;
        private static long _lastActivityTimestamp;
        private static bool _isBlinkPhase;
        private static uint _blinkCycleCount;
        private static bool _lastReportedConnected;
        private static bool _lastReportedBlink;
        private static bool _hasEverReported;

        public static event Action<bool, bool>? StateChanged;
        public static bool IsMidiConnected { get; private set; }
        public static bool IsBlinkPhase { get; private set; }

        public static bool IsRunning
        {
            get { lock (SyncLock) return _isRunning; }
        }

        public static NexControlHubStatus Status
        {
            get { lock (SyncLock) return _status; }
        }

        public static int LastStartErrorCode
        {
            get { lock (SyncLock) return _lastStartErrorCode; }
        }

        public static string? MidiDeviceName
        {
            get { lock (SyncLock) return _midiDeviceName; }
        }

        public static uint ActiveNodeId
        {
            get { lock (SyncLock) return _activeNodeId; }
        }

        private static string DecodeFixedUtf8(ReadOnlySpan<byte> buffer)
        {
            int nullIndex = buffer.IndexOf((byte)0);
            var slice = nullIndex >= 0 ? buffer.Slice(0, nullIndex) : buffer;
            return Encoding.UTF8.GetString(slice);
        }

        private static NexControlDeviceInfo FromNative(in NexControlDeviceInfoNative native)
        {
            return new NexControlDeviceInfo
            {
                StructSize = native.StructSize,
                PortId = DecodeFixedUtf8(MemoryMarshal.CreateReadOnlySpan(ref Unsafe.As<FixedUtf8Buffer64, byte>(ref Unsafe.AsRef(in native.PortId)), 64)),
                DisplayName = DecodeFixedUtf8(MemoryMarshal.CreateReadOnlySpan(ref Unsafe.As<FixedUtf8Buffer64, byte>(ref Unsafe.AsRef(in native.DisplayName)), 64)),
                ProfileModel = DecodeFixedUtf8(MemoryMarshal.CreateReadOnlySpan(ref Unsafe.As<FixedUtf8Buffer64, byte>(ref Unsafe.AsRef(in native.ProfileModel)), 64)),
                ProfileTier = native.ProfileTier,
                IsEnabled = native.IsEnabled,
                ConnectionState = native.ConnectionState
            };
        }

        private static NexControlTelemetrySnapshot FromNative(in NexControlTelemetrySnapshotNative native)
        {
            return new NexControlTelemetrySnapshot
            {
                StructSize = native.StructSize,
                PacketsReceived = native.PacketsReceived,
                DeltasApplied = native.DeltasApplied,
                P99LatencyMs = native.P99LatencyMs,
                ActiveInstances = native.ActiveInstances,
                MidiConnected = native.MidiConnected,
                MidiDeviceName = DecodeFixedUtf8(MemoryMarshal.CreateReadOnlySpan(ref Unsafe.As<FixedUtf8Buffer64, byte>(ref Unsafe.AsRef(in native.MidiDeviceName)), 64)),
                ClientConnected = native.ClientConnected,
                ClientPluginName = DecodeFixedUtf8(MemoryMarshal.CreateReadOnlySpan(ref Unsafe.As<FixedUtf8Buffer64, byte>(ref Unsafe.AsRef(in native.ClientPluginName)), 64)),
                ActiveNodeId = native.ActiveNodeId,
                LastCc = native.LastCc,
                LastDelta = native.LastDelta,
                TotalTicks = native.TotalTicks,
                LastActivityTimestampMs = native.LastActivityTimestampMs,
                BankMapSeq = native.BankMapSeq,
                ActiveVbankIndex = native.ActiveVbankIndex,
                TotalVbanks = native.TotalVbanks,
                ActiveHwBank = native.ActiveHwBank,
                LastEncoderMode = native.LastEncoderMode,
                LastMidiChannel = native.LastMidiChannel,
                LastBank = native.LastBank,
                LastMatched = native.LastMatched
            };
        }

        public static void Start()
        {
            var initialAllowedPorts = LoadAllowedPorts();
            byte initialGenericMode = GetSavedGenericEncoderMode();
            bool notify = false;
            bool started = false;
            lock (SyncLock)
            {
                if (_isRunning) return;

                try
                {
                    foreach (var portId in initialAllowedPorts)
                    {
                        if (!string.IsNullOrEmpty(portId))
                        {
                            nexcontrol_hub_set_port_enabled(portId, 1);
                        }
                    }

                    nexcontrol_hub_set_generic_encoder_mode(initialGenericMode);
                    int res = nexcontrol_hub_start(null);
                    _lastStartErrorCode = res;
                    if (res == 0)
                    {
                        _isRunning = true;
                        _status = NexControlHubStatus.Running;
                        _trackerCts = new CancellationTokenSource();
                        var token = _trackerCts.Token;
                        _trackerTask = Task.Run(() => RunInspectorTracker(token));
                        notify = true;
                        started = true;
                    }
                    else
                    {
                        _status = NexControlHubStatus.StartFailed;
                        notify = true;
                    }
                }
                catch (DllNotFoundException ex)
                {
                    _status = NexControlHubStatus.DllNotFound;
                    _lastStartErrorCode = -1;
                    notify = true;
                    Debug.WriteLine($"[NexControlBridge] Start failed (DllNotFound): {ex}");
                }
                catch (BadImageFormatException ex)
                {
                    _status = NexControlHubStatus.BadImageFormat;
                    _lastStartErrorCode = -1;
                    notify = true;
                    Debug.WriteLine($"[NexControlBridge] Start failed (BadImageFormat): {ex}");
                }
                catch (EntryPointNotFoundException ex)
                {
                    _status = NexControlHubStatus.EntryPointNotFound;
                    _lastStartErrorCode = -1;
                    notify = true;
                    Debug.WriteLine($"[NexControlBridge] Start failed (EntryPointNotFound): {ex}");
                }
                catch (Exception ex)
                {
                    _status = NexControlHubStatus.StartFailed;
                    _lastStartErrorCode = -1;
                    notify = true;
                    Debug.WriteLine($"[NexControlBridge] Start failed: {ex}");
                }
            }

            if (started)
            {
                AutoSelectFirstCompatibleDeviceIfNeeded();
            }

            if (notify)
            {
                InvokeStateChanged(false, false);
            }
        }

        public static void Stop()
        {
            Task? trackerToWait = null;
            CancellationTokenSource? ctsToDispose = null;

            lock (SyncLock)
            {
                if (!_isRunning) return;

                ctsToDispose = _trackerCts;
                _trackerCts = null;
                trackerToWait = _trackerTask;
                _trackerTask = null;

                ctsToDispose?.Cancel();

                try
                {
                    nexcontrol_hub_stop();
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] Stop failed: {ex}");
                }

                _isRunning = false;
                _status = NexControlHubStatus.Stopped;
                _midiDeviceName = null;
                _lastObservedTicks = 0;
                _lastObservedActivityMs = 0;
                _isBlinkPhase = false;
                _blinkCycleCount = 0;
                _lastReportedConnected = false;
                _lastReportedBlink = false;
                _hasEverReported = true;
                IsMidiConnected = false;
                IsBlinkPhase = false;
            }

            try
            {
                trackerToWait?.Wait(TimeSpan.FromSeconds(1));
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[NexControlBridge] Tracker join warning: {ex}");
            }
            ctsToDispose?.Dispose();

            InvokeStateChanged(false, false);
        }

        private static void InvokeStateChanged(bool connected, bool blink)
        {
            try
            {
                StateChanged?.Invoke(connected, blink);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[NexControlBridge] StateChanged handler error: {ex}");
            }
        }

        public static NexControlDeviceInfo[] GetConnectedDevices()
        {
            lock (SyncLock)
            {
                if (!_isRunning) return Array.Empty<NexControlDeviceInfo>();
                try
                {
                    uint count = nexcontrol_hub_get_device_count();
                    var devices = new List<NexControlDeviceInfo>((int)count);
                    for (uint i = 0; i < count; i++)
                    {
                        var native = new NexControlDeviceInfoNative
                        {
                            StructSize = (uint)Marshal.SizeOf<NexControlDeviceInfoNative>()
                        };
                        if (nexcontrol_hub_get_device_info(i, ref native) == 0)
                        {
                            devices.Add(FromNative(in native));
                        }
                    }
                    return devices.ToArray();
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] GetConnectedDevices failed: {ex}");
                    return Array.Empty<NexControlDeviceInfo>();
                }
            }
        }

        private static bool HasSavedPortConfiguration()
        {
            try
            {
                return File.Exists(GetPortsConfigPath());
            }
            catch
            {
                return false;
            }
        }

        private static void AutoSelectFirstCompatibleDeviceIfNeeded()
        {
            if (!IsRunning || HasSavedPortConfiguration()) return;
            lock (PortsConfigLock)
            {
                if (!IsRunning || HasSavedPortConfiguration()) return;
                try
                {
                    var devices = GetConnectedDevices();
                    NexControlDeviceInfo? best = null;
                    foreach (var dev in devices)
                    {
                        if ((dev.ProfileTier != 1 && dev.ProfileTier != 2) ||
                            dev.ConnectionState != 0 ||
                            string.IsNullOrEmpty(dev.PortId))
                        {
                            continue;
                        }

                        if (!best.HasValue ||
                            dev.ProfileTier < best.Value.ProfileTier ||
                            (dev.ProfileTier == best.Value.ProfileTier &&
                             StringComparer.OrdinalIgnoreCase.Compare(dev.DisplayName, best.Value.DisplayName) < 0))
                        {
                            best = dev;
                        }
                    }

                    if (!best.HasValue) return;

                    int rc = nexcontrol_hub_set_port_enabled(best.Value.PortId, 1);
                    if (rc == 0)
                    {
                        UpdateAllowedPortPersistenceUnlocked(best.Value.PortId, true);
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] AutoSelectFirstCompatibleDeviceIfNeeded failed: {ex}");
                }
            }
        }

        public static int SetPortEnabled(string portId, bool enabled)
        {
            if (string.IsNullOrWhiteSpace(portId)) return -1;
            lock (PortsConfigLock)
            {
                if (!IsRunning) return -1;
                try
                {
                    int rc = nexcontrol_hub_set_port_enabled(portId, enabled ? (byte)1 : (byte)0);
                    if (rc == 0)
                    {
                        UpdateAllowedPortPersistenceUnlocked(portId, enabled);
                    }
                    return rc;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] SetPortEnabled failed: {ex}");
                    return -1;
                }
            }
        }

        private static string GetPortsConfigPath()
        {
            var paths = new AppPaths();
            paths.EnsureDirectories();
            return Path.Combine(paths.StateDirectory, "nexcontrol_ports.json");
        }

        private static List<string> LoadAllowedPorts()
        {
            lock (PortsConfigLock)
            {
                try
                {
                    string filePath = GetPortsConfigPath();
                    if (!File.Exists(filePath)) return new List<string>();
                    string json = File.ReadAllText(filePath, Encoding.UTF8);
                    var cfg = JsonSerializer.Deserialize<NexControlPortsConfig>(json);
                    return cfg?.AllowedPorts ?? new List<string>();
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] LoadAllowedPorts warning: {ex}");
                    return new List<string>();
                }
            }
        }

        private static void UpdateAllowedPortPersistenceUnlocked(string portId, bool enabled)
        {
            try
                {
                    string filePath = GetPortsConfigPath();
                    var allowed = new List<string>();
                    if (File.Exists(filePath))
                    {
                        try
                        {
                            string existing = File.ReadAllText(filePath, Encoding.UTF8);
                            var parsed = JsonSerializer.Deserialize<NexControlPortsConfig>(existing);
                            if (parsed?.AllowedPorts != null)
                            {
                                allowed = parsed.AllowedPorts;
                            }
                        }
                        catch (Exception ex)
                        {
                            Debug.WriteLine($"[NexControlBridge] Corrupt nexcontrol_ports.json reset: {ex}");
                        }
                    }

                    if (enabled)
                    {
                        if (!allowed.Contains(portId)) allowed.Add(portId);
                    }
                    else
                    {
                        allowed.RemoveAll(p => string.Equals(p, portId, StringComparison.Ordinal));
                    }

                    var payload = JsonSerializer.Serialize(new NexControlPortsConfig { AllowedPorts = allowed });
                    string tmpPath = filePath + ".tmp";
                    File.WriteAllText(tmpPath, payload, Encoding.UTF8);
                    File.Move(tmpPath, filePath, overwrite: true);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] UpdateAllowedPortPersistence failed: {ex}");
                }
        }

        public static int ReloadProfiles(string? customDirPath = null)
        {
            lock (SyncLock)
            {
                if (!_isRunning) return -1;
                try
                {
                    return nexcontrol_hub_reload_profiles(customDirPath);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] ReloadProfiles failed: {ex}");
                    return -1;
                }
            }
        }

        private static string GetSettingsConfigPath()
        {
            var paths = new AppPaths();
            paths.EnsureDirectories();
            return Path.Combine(paths.StateDirectory, "nexcontrol_settings.json");
        }

        public static byte GetSavedGenericEncoderMode()
        {
            lock (SettingsConfigLock)
            {
                try
                {
                    string filePath = GetSettingsConfigPath();
                    if (!File.Exists(filePath)) return 4;
                    string json = File.ReadAllText(filePath, Encoding.UTF8);
                    var cfg = JsonSerializer.Deserialize<NexControlSettingsConfig>(json);
                    if (cfg?.GenericEncoderMode is byte mode && mode <= 4)
                    {
                        return mode;
                    }
                    return 4;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] GetSavedGenericEncoderMode warning: {ex}");
                    return 4;
                }
            }
        }

        public static int SetGenericEncoderMode(byte encoderMode)
        {
            if (encoderMode > 4) return -1;

            lock (SettingsConfigLock)
            {
                try
                {
                    string filePath = GetSettingsConfigPath();
                    var payload = JsonSerializer.Serialize(new NexControlSettingsConfig { GenericEncoderMode = encoderMode });
                    string tmpPath = filePath + ".tmp";
                    File.WriteAllText(tmpPath, payload, Encoding.UTF8);
                    File.Move(tmpPath, filePath, overwrite: true);
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] SaveGenericEncoderMode failed: {ex}");
                }
            }

            try
            {
                return nexcontrol_hub_set_generic_encoder_mode(encoderMode);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[NexControlBridge] SetGenericEncoderMode failed: {ex}");
                return -1;
            }
        }

        public static NexControlTelemetrySnapshot? GetTelemetry()
        {
            lock (SyncLock)
            {
                if (!_isRunning) return null;

                var native = new NexControlTelemetrySnapshotNative
                {
                    StructSize = (nuint)Marshal.SizeOf<NexControlTelemetrySnapshotNative>()
                };

                try
                {
                    if (nexcontrol_hub_get_telemetry(ref native) == 0)
                    {
                        return FromNative(in native);
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] GetTelemetry failed: {ex}");
                }

                return null;
            }
        }

        private static void RunInspectorTracker(CancellationToken token)
        {
            while (!token.IsCancellationRequested)
            {
                try
                {
                    if (!HasSavedPortConfiguration())
                    {
                        AutoSelectFirstCompatibleDeviceIfNeeded();
                    }

                    var native = new NexControlTelemetrySnapshotNative
                    {
                        StructSize = (nuint)Marshal.SizeOf<NexControlTelemetrySnapshotNative>()
                    };

                    if (nexcontrol_hub_get_telemetry(ref native) == 0)
                    {
                        var snap = FromNative(in native);
                        var isConnected = snap.MidiConnected != 0;
                        string? deviceName = isConnected && !string.IsNullOrWhiteSpace(snap.MidiDeviceName)
                            ? snap.MidiDeviceName
                            : null;

                        bool deviceNameChanged;
                        lock (SyncLock)
                        {
                            deviceNameChanged = !string.Equals(_midiDeviceName, deviceName, StringComparison.Ordinal);
                            _midiDeviceName = deviceName;
                        }

                        var hasNewTicks = (snap.TotalTicks != _lastObservedTicks && _lastObservedTicks != 0);
                        var hasNewActivityMs = (snap.LastActivityTimestampMs != _lastObservedActivityMs && _lastObservedActivityMs != 0);

                        if (hasNewTicks || hasNewActivityMs)
                        {
                            _lastActivityTimestamp = Stopwatch.GetTimestamp();
                        }
                        _lastObservedTicks = snap.TotalTicks;
                        _lastObservedActivityMs = snap.LastActivityTimestampMs;

                        var elapsedSec = _lastActivityTimestamp == 0
                            ? double.MaxValue
                            : (double)(Stopwatch.GetTimestamp() - _lastActivityTimestamp) / Stopwatch.Frequency;
                        var isRecentlyActive = elapsedSec < 0.35;

                        if (isConnected && isRecentlyActive)
                        {
                            _blinkCycleCount++;
                            if (_blinkCycleCount % 2 == 0)
                            {
                                _isBlinkPhase = !_isBlinkPhase;
                            }
                        }
                        else
                        {
                            _isBlinkPhase = false;
                            _blinkCycleCount = 0;
                        }

                        if (!_hasEverReported || isConnected != _lastReportedConnected || _isBlinkPhase != _lastReportedBlink || deviceNameChanged)
                        {
                            _hasEverReported = true;
                            _lastReportedConnected = isConnected;
                            _lastReportedBlink = _isBlinkPhase;
                            IsMidiConnected = isConnected;
                            IsBlinkPhase = _isBlinkPhase;
                            InvokeStateChanged(isConnected, _isBlinkPhase);
                        }
                    }

                    token.WaitHandle.WaitOne(60);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] RunInspectorTracker iteration error: {ex}");
                }
            }
        }
    }
}

