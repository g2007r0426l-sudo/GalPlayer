# -*- coding: utf-8 -*-
"""边抓 syslog 边启动 OnsPlayer，捕获引擎 stderr 输出"""
import io, os, subprocess, sys, time, threading, paramiko
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
    def run(cmd, t=60):
        _,o,e = c.exec_command(P + cmd, timeout=t)
        return (o.read().decode(errors="replace")+e.read().decode(errors="replace")).strip()

    # 抓 syslog 到设备文件（10 秒）
    print(run("(ls -t /var/mobile/Library/Logs/CrashReporter/*OnsPlayer*.ips | head -3) 2>/dev/null"))

    # 用 log stream 抓 OnsPlayer 输出；同时启动 app
    cmd = "nohup log stream --style compact --predicate 'process == \"OnsPlayer\"' > /tmp/ons.log 2>&1 & echo STREAM_STARTED"
    print(run(cmd))
    time.sleep(2)
    print(run("echo /var/mobile/Documents/Galgames/TestONS > /var/mobile/Documents/Galgames/.ons_launch; killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer && echo LAUNCHED"))
    time.sleep(10)
    print("=== OnsPlayer 日志 ===")
    print(run("cat /tmp/ons.log | tail -60"))
    print("=== 进程 ===")
    print(run("ps aux | grep -i onsplayer | grep -v grep | head -2"))
    print("=== 是否有新崩溃 ===")
    print(run("ls -la /var/mobile/Library/Logs/CrashReporter/*OnsPlayer*.ips 2>/dev/null | tail -2"))
    run("killall log 2>/dev/null")
    c.close()
finally:
    proxy.terminate()
