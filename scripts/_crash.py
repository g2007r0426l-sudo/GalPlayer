# -*- coding: utf-8 -*-
"""抓取 GalPlayer 崩溃日志关键段"""
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

    print("=== 最近的 GalPlayer 崩溃日志 ===")
    print(run("ls -t /var/mobile/Library/Logs/CrashReporter/*GalPlayer*.ips 2>/dev/null | head -3"))
    log = run("f=$(ls -t /var/mobile/Library/Logs/CrashReporter/*GalPlayer*.ips 2>/dev/null | head -1); echo \"FILE=$f\"; head -c 6000 \"$f\" 2>/dev/null")
    print(log)

    print("=== 崩溃线程回溯（找 GalPlayer 镜像帧）===")
    print(run("f=$(ls -t /var/mobile/Library/Logs/CrashReporter/*GalPlayer*.ips 2>/dev/null | head -1); grep -oE '\"imageIndex\":[0-9]+|\"symbol\":\"[^\"]*\"' \"$f\" 2>/dev/null | head -60"))
    c.close()
finally:
    proxy.terminate()
