# -*- coding: utf-8 -*-
"""直接测 OnsPlayer 引擎：写标记文件 -> 拉起播放器 -> 抓 syslog"""
import io, os, subprocess, sys, time, paramiko
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
subprocess.run(["taskkill","/F","/IM","iproxy.exe"], capture_output=True); time.sleep(1)
proxy = subprocess.Popen([IPROXY,"-u",UDID,"4494","44"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=4494, username="root", password="alpine", timeout=25,
              allow_agent=False, look_for_keys=False)
    def run(cmd, t=300):
        _,o,e = c.exec_command(P + cmd, timeout=t)
        return (o.read().decode(errors="replace")+e.read().decode(errors="replace")).strip()

    print(run("echo /var/mobile/Documents/Galgames/TestONS > /var/mobile/Documents/Galgames/.ons_launch && cat /var/mobile/Documents/Galgames/.ons_launch"))
    print(run("killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer && echo LAUNCHED"))
    time.sleep(8)
    print("=== 进程 ===")
    print(run("ps aux | grep -i onsplayer | grep -v grep | head -3"))
    print("=== 崩溃日志（若有）===")
    print(run("ls -t /var/mobile/Library/Logs/CrashReporter/*OnsPlayer*.ips 2>/dev/null | head -2"))
    c.close()
finally:
    proxy.terminate()
