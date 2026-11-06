using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Automation;

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
        private static Process? _refreshProcess;
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
                        StartRefreshDaemon();
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

                StopRefreshDaemon();

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

        private static void StartRefreshDaemon()
        {
            if (_refreshProcess != null && !_refreshProcess.HasExited) return;

            string baseDir = AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(baseDir, "resolve_refresh_daemon.py");
            if (!File.Exists(scriptPath))
            {
                string envPath = Environment.GetEnvironmentVariable("MCNEXUS_REFRESH_DAEMON_PATH") ?? string.Empty;
                if (File.Exists(envPath)) scriptPath = envPath;
            }

            if (!File.Exists(scriptPath)) return;

            string[] candidates = new[]
            {
                "python.exe",
                "py.exe",
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python311", "python.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python310", "python.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Python", "Python39", "python.exe"),
                @"C:\Python311\python.exe",
                @"C:\Python310\python.exe",
                @"C:\Python39\python.exe"
            };

            string pythonExe = "python.exe";
            foreach (var cand in candidates)
            {
                if (Path.IsPathRooted(cand))
                {
                    if (File.Exists(cand)) { pythonExe = cand; break; }
                }
                else
                {
                    pythonExe = cand;
                    break;
                }
            }

            try
            {
                var psi = new ProcessStartInfo
                {
                    FileName = pythonExe,
                    Arguments = $"\"{scriptPath}\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };
                _refreshProcess = Process.Start(psi);
            }
            catch (Exception ex)
            {
                Debug.WriteLine($"[NexControlBridge] StartRefreshDaemon failed: {ex}");
            }
        }

        private static void StopRefreshDaemon()
        {
            if (_refreshProcess != null)
            {
                try
                {
                    if (!_refreshProcess.HasExited)
                    {
                        _refreshProcess.Kill();
                    }
                }
                catch {}
                finally
                {
                    _refreshProcess.Dispose();
                    _refreshProcess = null;
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
                try
                {
                    uint foundId = ScanResolveAutomation();
                    lock (SyncLock)
                    {
                        if (_activeNodeId != foundId)
                        {
                            _activeNodeId = foundId;
                            nexcontrol_hub_set_active_node(foundId);
                        }
                    }
                }
                catch
                {
                    // Ignore UIAutomation traversal glitches
                }

                try
                {
                    Thread.Sleep(150);
                }
                catch
                {
                    break;
                }
            }
        }

        private static uint ScanResolveAutomation()
        {
            Process[] resolveProcesses = Process.GetProcessesByName("Resolve");
            if (resolveProcesses.Length == 0) return 0;

            foreach (var proc in resolveProcesses)
            {
                if (proc.MainWindowHandle == IntPtr.Zero) continue;
                try
                {
                    var rootElem = AutomationElement.FromHandle(proc.MainWindowHandle);
                    if (rootElem == null) continue;

                    uint foundId = SearchElementRecursive(rootElem, 0);
                    if (foundId > 0) return foundId;
                }
                catch
                {
                    // continue
                }
            }

            return 0;
        }

        private static uint SearchElementRecursive(AutomationElement element, int depth)
        {
            if (depth > 10) return 0;

            try
            {
                string name = element.Current.Name ?? string.Empty;
                if (name.Contains("ID: "))
                {
                    int idx = name.IndexOf("ID: ", StringComparison.Ordinal);
                    string numPart = name.Substring(idx + 4).Trim();
                    int end = 0;
                    while (end < numPart.Length && char.IsDigit(numPart[end])) end++;
                    if (end > 0 && uint.TryParse(numPart.Substring(0, end), out uint id))
                    {
                        return id;
                    }
                }

                var children = element.FindAll(TreeScope.Children, Condition.TrueCondition);
                foreach (AutomationElement child in children)
                {
                    uint id = SearchElementRecursive(child, depth + 1);
                    if (id > 0) return id;
                }
            }
            catch
            {
                // ignore
            }

            return 0;
        }
    }
}

