# -*- coding: utf-8 -*-
"""在设备上安装已推送的 GalPlayer.deb"""
import paramiko, subprocess, time, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
HOST_PORT = 4494

PATH_PREFIX = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:"
               "/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")

subprocess.run(["taskkill", "/F", "/IM", "iproxy.exe"], capture_output=True)
time.sleep(1)
proxy = subprocess.Popen([IPROXY, "-u", UDID, str(HOST_PORT), "44"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=HOST_PORT, username="root", password="alpine",
              timeout=25, allow_agent=False, look_for_keys=False)

    def run(cmd, t=900):
        _, o, e = c.exec_command(PATH_PREFIX + cmd, timeout=t)
        return (o.read().decode(errors="replace") + e.read().decode(errors="replace")).strip()

    print("=== 1. 就位检查 ===")
    print(run("ls -la /var/mobile/Media/Downloads/GalPlayer.deb"))
    print(run("cp -f /var/mobile/Media/Downloads/GalPlayer.deb /var/mobile/GalPlayer.deb && echo COPIED"))

    print("=== 2. dpkg -i 安装 ===")
    print(run("dpkg -i /var/mobile/GalPlayer.deb 2>&1 | tail -25"))

    print("=== 3. 验证安装 ===")
    print(run("ls -la /var/jb/Applications/ 2>/dev/null"))
    print(run("ls -la /var/jb/Applications/GalPlayer.app 2>/dev/null | head -12"))
    print(run("dpkg -l | grep -i galplayer"))
finally:
    c.close() if 'c' in dir() else None
    proxy.terminate()
