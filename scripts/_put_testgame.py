# -*- coding: utf-8 -*-
"""放置最小 ONScripter 测试游戏并刷新 App"""
import io, os, sys, subprocess, time, paramiko
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
HOST_PORT = 4494
PATH_PREFIX = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:"
               "/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")

# 最小 NScripter 文本脚本（0.txt 由 ONScripter 直接读取）
SCRIPT = """*define
game
*start
bg black,1
`GalPlayer engine test OK!
`ONScripter is running on iPad.
click
end
"""

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

    print(run("mkdir -p /var/mobile/Documents/Galgames/TestONS && echo MKDIR_OK"))
    # 用 base64 传输避免引号/编码问题
    import base64
    b64 = base64.b64encode(SCRIPT.encode("utf-8")).decode()
    print(run(f"echo '{b64}' | base64 -d > /var/mobile/Documents/Galgames/TestONS/0.txt && echo WRITE_OK"))
    print(run("chown -R mobile:mobile /var/mobile/Documents/Galgames/TestONS && ls -la /var/mobile/Documents/Galgames/TestONS && cat /var/mobile/Documents/Galgames/TestONS/0.txt | head -6"))

    # 重启 App 以触发扫描
    print(run("killall GalPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.galplayer && echo REOPEN_OK"))
    c.close()
finally:
    proxy.terminate()
