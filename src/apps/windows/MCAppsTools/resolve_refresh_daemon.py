#!/usr/bin/env python3
"""
MCNexus Resolve Viewer Refresh Daemon
Ensures immediate GPU refresh during playback pause in DaVinci Resolve Studio.
Implements Render-Aware Backpressure with trailing-edge delivery guarantee.
"""
import sys
import os
import time
import socket
import select
import threading

# Flexible discovery of DaVinci Resolve Scripting API modules
script_api_env = os.environ.get("RESOLVE_SCRIPT_API")
if script_api_env:
    custom_modules = os.path.join(script_api_env, "Modules")
    if os.path.isdir(custom_modules) and custom_modules not in sys.path:
        sys.path.insert(0, custom_modules)

if sys.platform == "win32":
    prog_data = os.environ.get("PROGRAMDATA", r"C:\ProgramData")
    std_modules = os.path.join(prog_data, "Blackmagic Design", "DaVinci Resolve", "Support", "Developer", "Scripting", "Modules")
else:
    std_modules = '/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting/Modules'

if os.path.isdir(std_modules) and std_modules not in sys.path:
    sys.path.append(std_modules)

class ResolveRefresher:
    def __init__(self):
        self.resolve = None
        self.project_manager = None
        self.current_project = None
        self.current_timeline = None
        self.last_resolve_check = 0.0

        self.needs_refresh = False
        self.running = True
        self.cond = threading.Condition()
        self.min_interval = 0.05  # Rate-limit to max 20 Hz (50 ms) to avoid GPU run loop contention

    def get_timeline(self):
        now = time.perf_counter()
        if self.current_timeline and (now - self.last_resolve_check) < 2.0:
            return self.current_timeline

        self.last_resolve_check = now
        try:
            import DaVinciResolveScript as dvr_script
            if not self.resolve:
                self.resolve = dvr_script.scriptapp('Resolve')
            if not self.resolve:
                self.current_timeline = None
                return None

            self.project_manager = self.resolve.GetProjectManager()
            if not self.project_manager:
                self.current_timeline = None
                return None

            self.current_project = self.project_manager.GetCurrentProject()
            if not self.current_project:
                self.current_timeline = None
                return None

            self.current_timeline = self.current_project.GetCurrentTimeline()
            return self.current_timeline
        except Exception:
            self.resolve = None
            self.current_timeline = None
            return None

    def request_refresh(self):
        with self.cond:
            self.needs_refresh = True
            self.cond.notify()

    def worker_loop(self):
        last_refresh_time = 0.0

        while self.running:
            with self.cond:
                while self.running and not self.needs_refresh:
                    self.cond.wait(timeout=0.2)

                if not self.running:
                    break

                self.needs_refresh = False

            # Throttle backpressure: await minimum interval to avoid overloading host run loop
            now = time.perf_counter()
            elapsed = now - last_refresh_time
            if elapsed < self.min_interval:
                time.sleep(self.min_interval - elapsed)

            timeline = self.get_timeline()
            if timeline:
                try:
                    tc = timeline.GetCurrentTimecode()
                    if tc:
                        timeline.SetCurrentTimecode(tc)
                        last_refresh_time = time.perf_counter()
                except Exception:
                    self.current_timeline = None
                    self.resolve = None


def main():
    # UDP listening socket creation
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    except Exception:
        pass

    port_env = os.environ.get("MCNEXUS_REFRESH_UDP_PORT", "28752")
    try:
        udp_port = int(port_env)
    except ValueError:
        udp_port = 28752

    try:
        sock.bind(("127.0.0.1", udp_port))
    except Exception as e:
        # Another instance is already listening on this port
        sys.exit(0)

    sock.setblocking(False)

    refresher = ResolveRefresher()
    worker_thread = threading.Thread(target=refresher.worker_loop, daemon=True)
    worker_thread.start()

    try:
        while True:
            r, _, _ = select.select([sock], [], [], 0.5)
            if r:
                # Drain all pending accumulated pings
                while True:
                    try:
                        data, _ = sock.recvfrom(1024)
                    except BlockingIOError:
                        break
                    except Exception:
                        break

                refresher.request_refresh()
    except (KeyboardInterrupt, SystemExit):
        refresher.running = False
        with refresher.cond:
            refresher.cond.notify_all()
    finally:
        sock.close()


if __name__ == '__main__':
    main()
