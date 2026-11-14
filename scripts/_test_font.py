# -*- coding: utf-8 -*-
"""实验：换字体 + 换脚本编码，观察字形变化"""
import io, os, subprocess, sys, time, paramiko, base64
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
    def run(cmd, t=180):
        _,o,e = c.exec_command(P + cmd, timeout=t)
        return (o.read().decode(errors="replace")+e.read().decode(errors="replace")).strip()

    mode = sys.argv[1] if len(sys.argv) > 1 else "utf8"

    # 1) 字体替换（用 GalPlayer 包里的霞鹜文楷）
    print(run("cp -f /var/jb/Applications/GalPlayer.app/LXGWWenKai-Regular.ttf "
              "/var/jb/Applications/OnsPlayer.app/DroidSansFallback.ttf && echo FONT_SWAPPED"))
    print(run("ls -la /var/jb/Applications/OnsPlayer.app/*.ttf"))

    # 2) 脚本：UTF-8 版（含中文日文）
    script = """*define
game
*start
bg black,1
`こんにちは　ギャルゲー
`中文测试 中文测试
`ABC abc 123
click
end
"""
    enc = "utf-8" if mode == "utf8" else "cp932"
    b64 = base64.b64encode(script.encode(enc, errors="replace")).decode()
    print(run(f"echo '{b64}' | base64 -d > /var/mobile/Documents/Galgames/TestONS/0.txt && echo WRITE_OK"))
    print(run("chown mobile:mobile /var/mobile/Documents/Galgames/TestONS/0.txt"))

    print(run("echo /var/mobile/Documents/Galgames/TestONS > /var/mobile/Documents/Galgames/.ons_launch; "
              "killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer && echo LAUNCHED"))
    time.sleep(8)
    print("进程数:", run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    c.close()
finally:
    proxy.terminate()
