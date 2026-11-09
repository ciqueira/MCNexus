using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Threading;

namespace MCAppsTools.Services
{
    public sealed class TrayIconService : IDisposable
    {
        private const uint NimAdd = 0x00000000;
        private const uint NimModify = 0x00000001;
        private const uint NimDelete = 0x00000002;

        private const uint NifMessage = 0x00000001;
        private const uint NifIcon = 0x00000002;
        private const uint NifTip = 0x00000004;

        private const int WmUser = 0x0400;
        private const int WmTrayCallback = WmUser + 101;
        private const int WmLButtonUp = 0x0202;
        private const int WmLButtonDblClk = 0x0203;
        private const int WmRButtonUp = 0x0205;
        private const int WmContextMenu = 0x007B;

        private const uint MfString = 0x00000000;
        private const uint MfGrayed = 0x00000001;
        private const uint MfDisabled = 0x00000002;
        private const uint MfSeparator = 0x00000800;
        private const uint TpmReturnCmd = 0x0100;
        private const uint TpmNoNotify = 0x0080;
        private const uint TpmRightButton = 0x0002;

        private const uint ImageIcon = 1;
        private const uint LoadFromFile = 0x0010;

        private const uint CmdOpen = 1001;
        private const uint CmdToggleHub = 1002;
        private const uint CmdReloadProfiles = 1003;
        private const uint CmdQuit = 1004;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct NOTIFYICONDATA
        {
            public uint cbSize;
            public IntPtr hWnd;
            public uint uID;
            public uint uFlags;
            public uint uCallbackMessage;
            public IntPtr hIcon;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)]
            public string szTip;
            public uint dwState;
            public uint dwStateMask;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)]
            public string szInfo;
            public uint uTimeoutOrVersion;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)]
            public string szInfoTitle;
            public uint dwInfoFlags;
            public Guid guidItem;
            public IntPtr hBalloonIcon;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int X;
            public int Y;
        }

        [DllImport("shell32.dll", CharSet = CharSet.Unicode)]
        private static extern bool Shell_NotifyIcon(uint dwMessage, ref NOTIFYICONDATA lpData);

        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        private static extern IntPtr LoadImage(IntPtr hInst, string name, uint type, int cx, int cy, uint fuLoad);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("user32.dll")]
        private static extern IntPtr CreatePopupMenu();

        [DllImport("user32.dll")]
        private static extern bool DestroyMenu(IntPtr hMenu);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool AppendMenu(IntPtr hMenu, uint uFlags, uint uIDNewItem, string lpNewItem);

        [DllImport("user32.dll")]
        private static extern uint TrackPopupMenuEx(IntPtr hmenu, uint fuFlags, int x, int y, IntPtr hwnd, IntPtr lptpm);

        [DllImport("user32.dll")]
        private static extern bool GetCursorPos(out POINT lpPoint);

        [DllImport("user32.dll")]
        private static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern uint RegisterWindowMessage(string lpString);

        private readonly Dispatcher _dispatcher;
        private bool _isLightTheme;
        private bool _isInitialized;
        private bool _isDisposed;

        private HwndSource? _hwndSource;
        private IntPtr _messageHwnd;
        private uint _wmTaskbarCreated;

        private IntPtr _hIconDisconnected;
        private IntPtr _hIconConnectedIdle;
        private IntPtr _hIconConnectedActive;
        private IntPtr _currentHIcon;

        private bool _isMidiConnected;
        private bool _isBlinkPhase;

        public TrayIconService(bool isLightTheme)
        {
            _dispatcher = Application.Current?.Dispatcher ?? Dispatcher.CurrentDispatcher;
            _isLightTheme = isLightTheme;
        }

        public void Initialize()
        {
            if (_isInitialized || _isDisposed)
            {
                return;
            }

            _wmTaskbarCreated = RegisterWindowMessage("TaskbarCreated");

            var parameters = new HwndSourceParameters("MCNexusTrayListener")
            {
                Width = 0,
                Height = 0,
                PositionX = -10000,
                PositionY = -10000,
                WindowStyle = unchecked((int)0x80000000) // WS_POPUP (hidden, non-activating)
            };

            _hwndSource = new HwndSource(parameters);
            _hwndSource.AddHook(WndProc);
            _messageHwnd = _hwndSource.Handle;

            LoadThemeIcons();

            _isMidiConnected = NexControlBridge.IsMidiConnected;
            _isBlinkPhase = NexControlBridge.IsBlinkPhase;
            _currentHIcon = GetTargetIconHandle();

            AddNotifyIcon();

            NexControlBridge.StateChanged += OnBridgeStateChanged;
            _isInitialized = true;
        }

        public void RefreshTheme(bool isLightTheme)
        {
            if (_isDisposed)
            {
                return;
            }

            _dispatcher.InvokeAsync(() =>
            {
                if (_isLightTheme == isLightTheme && _hIconConnectedIdle != IntPtr.Zero)
                {
                    return;
                }

                _isLightTheme = isLightTheme;
                LoadThemeIcons();
                UpdateTrayIcon();
            });
        }

        private void OnBridgeStateChanged(bool isConnected, bool isBlinkPhase)
        {
            if (_isDisposed)
            {
                return;
            }

            _dispatcher.InvokeAsync(() =>
            {
                _isMidiConnected = isConnected;
                _isBlinkPhase = isBlinkPhase;
                UpdateTrayIcon();
            });
        }

        private void LoadThemeIcons()
        {
            ReleaseThemeIcons();

            var suffix = _isLightTheme ? "Light" : "Dark";
            _hIconDisconnected = LoadNativeIcon($"HubDisconnected{suffix}.ico");
            _hIconConnectedIdle = LoadNativeIcon($"HubConnected{suffix}.ico");
            _hIconConnectedActive = LoadNativeIcon($"HubActive{suffix}.ico");
        }

        private void ReleaseThemeIcons()
        {
            if (_hIconDisconnected != IntPtr.Zero)
            {
                DestroyIcon(_hIconDisconnected);
                _hIconDisconnected = IntPtr.Zero;
            }

            if (_hIconConnectedIdle != IntPtr.Zero)
            {
                DestroyIcon(_hIconConnectedIdle);
                _hIconConnectedIdle = IntPtr.Zero;
            }

            if (_hIconConnectedActive != IntPtr.Zero)
            {
                DestroyIcon(_hIconConnectedActive);
                _hIconConnectedActive = IntPtr.Zero;
            }

            _currentHIcon = IntPtr.Zero;
        }

        private IntPtr GetTargetIconHandle()
        {
            if (!_isMidiConnected)
            {
                return _hIconDisconnected != IntPtr.Zero ? _hIconDisconnected : _hIconConnectedIdle;
            }

            if (_isBlinkPhase && _hIconConnectedActive != IntPtr.Zero)
            {
                return _hIconConnectedActive;
            }

            return _hIconConnectedIdle != IntPtr.Zero ? _hIconConnectedIdle : _hIconDisconnected;
        }

        private void AddNotifyIcon()
        {
            if (_messageHwnd == IntPtr.Zero || _isDisposed)
            {
                return;
            }

            var data = new NOTIFYICONDATA
            {
                cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                hWnd = _messageHwnd,
                uID = 1,
                uFlags = NifMessage | NifIcon | NifTip,
                uCallbackMessage = WmTrayCallback,
                hIcon = _currentHIcon,
                szTip = "MCNexus - NexControl MIDI Hub"
            };

            Shell_NotifyIcon(NimAdd, ref data);
        }

        private void UpdateTrayIcon()
        {
            if (_messageHwnd == IntPtr.Zero || _isDisposed)
            {
                return;
            }

            var newIcon = GetTargetIconHandle();
            if (newIcon == IntPtr.Zero || newIcon == _currentHIcon)
            {
                return;
            }

            _currentHIcon = newIcon;

            var data = new NOTIFYICONDATA
            {
                cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                hWnd = _messageHwnd,
                uID = 1,
                uFlags = NifIcon,
                hIcon = _currentHIcon
            };

            Shell_NotifyIcon(NimModify, ref data);
        }

        private void RemoveNotifyIcon()
        {
            if (_messageHwnd == IntPtr.Zero)
            {
                return;
            }

            var data = new NOTIFYICONDATA
            {
                cbSize = (uint)Marshal.SizeOf<NOTIFYICONDATA>(),
                hWnd = _messageHwnd,
                uID = 1
            };

            Shell_NotifyIcon(NimDelete, ref data);
        }

        private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
        {
            if (_wmTaskbarCreated != 0 && msg == (int)_wmTaskbarCreated)
            {
                AddNotifyIcon();
                handled = true;
                return IntPtr.Zero;
            }

            if (msg == WmTrayCallback)
            {
                var mouseMsg = (int)lParam;
                switch (mouseMsg)
                {
                    case WmLButtonDblClk:
                        App.OpenOrRestoreMainWindow();
                        handled = true;
                        break;

                    case WmLButtonUp:
                    case WmRButtonUp:
                    case WmContextMenu:
                        ShowContextMenu();
                        handled = true;
                        break;
                }
            }

            return IntPtr.Zero;
        }

        private void ShowContextMenu()
        {
            if (_messageHwnd == IntPtr.Zero)
            {
                return;
            }

            var hMenu = CreatePopupMenu();
            if (hMenu == IntPtr.Zero)
            {
                return;
            }

            var telemetry = NexControlBridge.GetTelemetry();
            var devices = NexControlBridge.GetConnectedDevices();

            // 1. Header
            AppendMenu(hMenu, MfString | MfDisabled, 0, "NexControl MIDI Hub");
            AppendMenu(hMenu, MfSeparator, 0, string.Empty);

            // 2. MIDI Hardware Section
            AppendMenu(hMenu, MfString | MfDisabled, 0, "MIDI Hardware");
            if (telemetry.HasValue && telemetry.Value.MidiConnected != 0)
            {
                var activeName = string.IsNullOrWhiteSpace(telemetry.Value.MidiDeviceName)
                    ? "Unknown"
                    : telemetry.Value.MidiDeviceName;
                AppendMenu(hMenu, MfString | MfDisabled, 0, $"  Active: {activeName}");

                foreach (var dev in devices)
                {
                    var tier = dev.ProfileTier switch
                    {
                        1 => "Custom",
                        2 => "Homologated",
                        _ => "Generic"
                    };
                    AppendMenu(hMenu, MfString | MfDisabled, 0, $"  • {dev.DisplayName} [{tier}]");
                }
            }
            else
            {
                AppendMenu(hMenu, MfString | MfDisabled, 0, "  Device: None detected");
            }

            AppendMenu(hMenu, MfString, CmdReloadProfiles, "Reload Custom Profiles");
            AppendMenu(hMenu, MfSeparator, 0, string.Empty);

            // 3. Knob Activity Section
            AppendMenu(hMenu, MfString | MfDisabled, 0, "Knob Activity");
            string lastActivityText;
            if (telemetry.HasValue && telemetry.Value.TotalTicks > 0)
            {
                var deltaDir = telemetry.Value.LastDelta > 0
                    ? $"+{telemetry.Value.LastDelta} (CW)"
                    : (telemetry.Value.LastDelta < 0 ? $"{telemetry.Value.LastDelta} (CCW)" : "Click");
                lastActivityText = $"  CC {telemetry.Value.LastCc} -> {deltaDir} [{telemetry.Value.TotalTicks} ticks]";
            }
            else
            {
                lastActivityText = "  No rotation detected";
            }
            AppendMenu(hMenu, MfString | MfDisabled, 0, lastActivityText);

            if (telemetry.HasValue && telemetry.Value.TotalTicks > 0)
            {
                AppendMenu(hMenu, MfString | MfDisabled, 0, $"  Accumulated total: {telemetry.Value.TotalTicks} ticks");
            }

            AppendMenu(hMenu, MfSeparator, 0, string.Empty);

            // 4. Start / Pause MIDI Hub
            var toggleText = NexControlBridge.IsRunning ? "Pause MIDI Hub" : "Start MIDI Hub";
            AppendMenu(hMenu, MfString, CmdToggleHub, toggleText);
            AppendMenu(hMenu, MfSeparator, 0, string.Empty);

            // 5. Open MCNexus & Quit MCNexus
            AppendMenu(hMenu, MfString, CmdOpen, "Open MCNexus");
            AppendMenu(hMenu, MfSeparator, 0, string.Empty);
            AppendMenu(hMenu, MfString, CmdQuit, "Quit MCNexus");

            GetCursorPos(out var pt);
            SetForegroundWindow(_messageHwnd);
            var cmd = TrackPopupMenuEx(hMenu, TpmReturnCmd | TpmNoNotify | TpmRightButton, pt.X, pt.Y, _messageHwnd, IntPtr.Zero);
            DestroyMenu(hMenu);

            switch (cmd)
            {
                case CmdOpen:
                    App.OpenOrRestoreMainWindow();
                    break;

                case CmdToggleHub:
                    if (NexControlBridge.IsRunning)
                    {
                        NexControlBridge.Stop();
                    }
                    else
                    {
                        NexControlBridge.Start();
                    }
                    break;

                case CmdReloadProfiles:
                    NexControlBridge.ReloadProfiles();
                    break;

                case CmdQuit:
                    App.QuitApplication();
                    break;
            }
        }

        private static IntPtr LoadNativeIcon(string fileName)
        {
            var path = ResolveIconPath(fileName);
            if (path is null)
            {
                Debug.WriteLine($"[TrayIconService] Icon file not found: {fileName}");
                return IntPtr.Zero;
            }

            return LoadImage(IntPtr.Zero, path, ImageIcon, 16, 16, LoadFromFile);
        }

        private static string? ResolveIconPath(string fileName)
        {
            var candidates = new[]
            {
                Path.Combine(AppContext.BaseDirectory, fileName),
                Path.Combine(AppContext.BaseDirectory, "Assets", fileName)
            };

            foreach (var candidate in candidates)
            {
                if (File.Exists(candidate))
                {
                    return candidate;
                }
            }

            return null;
        }

        public void Dispose()
        {
            if (_isDisposed)
            {
                return;
            }

            _isDisposed = true;
            NexControlBridge.StateChanged -= OnBridgeStateChanged;

            RemoveNotifyIcon();
            ReleaseThemeIcons();

            if (_hwndSource != null)
            {
                _hwndSource.RemoveHook(WndProc);
                _hwndSource.Dispose();
                _hwndSource = null;
            }

            _messageHwnd = IntPtr.Zero;
        }
    }
}
