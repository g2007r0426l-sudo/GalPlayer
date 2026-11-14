# -*- coding: utf-8 -*-
"""检查设备游戏目录 + 可选启动测试"""
import io, os, sys, subprocess, time, paramiko
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

    def run(cmd, t=300):
        _, o, e = c.exec_command(PATH_PREFIX + cmd, timeout=t)
        return (o.read().decode(errors="replace") + e.read().decode(errors="replace")).strip()

    print("=== Galgames 目录 ===")
    print(run("ls -la /var/mobile/Documents/Galgames/ 2>/dev/null || echo '目录不存在'"))
    print("=== 每个游戏目录内容 ===")
    print(run("for d in /var/mobile/Documents/Galgames/*/; do echo \"--- $d\"; ls \"$d\" | head -8; done 2>/dev/null"))
    print("=== App 进程 ===")
    print(run("ps aux | grep -i galplayer | grep -v grep | head -3"))
    print("=== 崩溃日志（最近）===")
    print(run("ls -t /var/mobile/Library/Logs/CrashReporter/*.ips 2>/dev/null | head -3"))
    c.close()
finally:
    proxy.terminate()
