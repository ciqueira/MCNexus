using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace MCAppsTools.Services
{
    [StructLayout(LayoutKind.Sequential, Pack = 8)]
    public struct NexControlDeviceInfo
    {
        public uint StructSize;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string PortId;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string DisplayName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string ProfileModel;
        public byte ProfileTier;
        private byte _res0;
        private byte _res1;
        private byte _res2;
    }

    [StructLayout(LayoutKind.Sequential, Pack = 8)]
    public struct NexControlTelemetrySnapshot
    {
        public nuint StructSize;
        public ulong PacketsReceived;
        public ulong DeltasApplied;
        public double P99LatencyMs;
        public uint ActiveInstances;
        public byte MidiConnected;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string MidiDeviceName;
        public byte ClientConnected;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
        public string ClientPluginName;
        public uint ActiveNodeId;
        public byte LastCc;
        public sbyte LastDelta;
        public ulong TotalTicks;
        public ulong LastActivityTimestampMs;
    }

    public static class NexControlBridge
    {
        private const string DllName = "nexcontrol_hub";

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int nexcontrol_hub_start([MarshalAs(UnmanagedType.LPUTF8Str)] string? socketPath);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int nexcontrol_hub_stop();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int nexcontrol_hub_set_active_node(uint instanceId);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        private static extern int nexcontrol_hub_get_telemetry(ref NexControlTelemetrySnapshot outSnapshot);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern uint nexcontrol_hub_get_device_count();

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int nexcontrol_hub_get_device_info(uint index, ref NexControlDeviceInfo outInfo);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int nexcontrol_hub_set_generic_encoder_mode(byte encoderMode);

        [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
        public static extern int nexcontrol_hub_reload_profiles([MarshalAs(UnmanagedType.LPUTF8Str)] string? customDirPath);

        private static bool _isRunning;
        private static uint _activeNodeId;
        private static CancellationTokenSource? _trackerCts;
        private static readonly object SyncLock = new();

        public static bool IsRunning
        {
            get { lock (SyncLock) return _isRunning; }
        }

        public static uint ActiveNodeId
        {
            get { lock (SyncLock) return _activeNodeId; }
        }

        public static void Start()
        {
            lock (SyncLock)
            {
                if (_isRunning) return;

                try
                {
                    int res = nexcontrol_hub_start(null);
                    if (res == 0)
                    {
                        _isRunning = true;
                        _trackerCts = new CancellationTokenSource();
                        Task.Run(() => RunInspectorTracker(_trackerCts.Token));
                    }
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] Start failed: {ex}");
                }
            }
        }

        public static void Stop()
        {
            lock (SyncLock)
            {
                if (!_isRunning) return;

                _trackerCts?.Cancel();
                _trackerCts = null;

                try
                {
                    nexcontrol_hub_stop();
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] Stop failed: {ex}");
                }

                _isRunning = false;
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
                    var devices = new NexControlDeviceInfo[count];
                    for (uint i = 0; i < count; i++)
                    {
                        var info = new NexControlDeviceInfo
                        {
                            StructSize = (uint)Marshal.SizeOf<NexControlDeviceInfo>()
                        };
                        if (nexcontrol_hub_get_device_info(i, ref info) == 0)
                        {
                            devices[i] = info;
                        }
                    }
                    return devices;
                }
                catch (Exception ex)
                {
                    Debug.WriteLine($"[NexControlBridge] GetConnectedDevices failed: {ex}");
                    return Array.Empty<NexControlDeviceInfo>();
                }
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

        public static int SetGenericEncoderMode(byte encoderMode)
        {
            lock (SyncLock)
            {
                if (!_isRunning) return -1;
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
        }

        public static NexControlTelemetrySnapshot? GetTelemetry()
        {
            lock (SyncLock)
            {
                if (!_isRunning) return null;

                var snap = new NexControlTelemetrySnapshot
                {
                    StructSize = (nuint)Marshal.SizeOf<NexControlTelemetrySnapshot>()
                };

                try
                {
                    if (nexcontrol_hub_get_telemetry(ref snap) == 0)
                    {
                        return snap;
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
                // Active node is reported in-process by the OFX plugin via IPC to NexControlHub.
                try
                {
                    Thread.Sleep(200);
                }
                catch
                {
                    break;
                }
            }
        }
    }
}

