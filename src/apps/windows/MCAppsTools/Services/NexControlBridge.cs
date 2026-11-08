using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;

namespace MCAppsTools.Services
{
    [StructLayout(LayoutKind.Sequential)]
    public struct NexControlTelemetrySnapshot
    {
        public nuint StructSize;
        public ulong PacketsReceived;
        public ulong DeltasApplied;
        public double P99LatencyMs;
        public uint ActiveInstances;
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

