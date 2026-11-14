# -*- coding: utf-8 -*-
"""在设备上生成一个演示用 ONS 游戏（UTF-8 脚本 + 背景图）"""
import io, os, subprocess, sys, time, paramiko, base64
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
GAME = "/var/mobile/Documents/Galgames/TestONS"
BG = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer\app\GalPlayer\Resources\covers_wide\wide2.jpg"

# UTF-8 脚本：文本标记是 '^'
script = """*define
game
*start
bg "bg.jpg",1
^こんにちは、はじめまして。
^这是 GalPlayer 的中文测试行。
^Tap to continue / long press to skip / two fingers for menu
click
end
"""
data = script.encode("utf-8")

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

    run(f"mkdir -p {GAME}")
    b64 = base64.b64encode(data).decode()
    print(run(f"echo '{b64}' | base64 -d > {GAME}/0.txt && echo SCRIPT_OK"))
    bg64 = base64.b64encode(open(BG, "rb").read()).decode()
    print(run(f"echo '{bg64}' | base64 -d > {GAME}/bg.jpg && echo BG_OK"))
    print(run(f"ls -la {GAME}"))
    print(run("chown -R mobile:mobile /var/mobile/Documents/Galgames/TestONS"))
    print(run(f"echo {GAME} > /var/mobile/Documents/Galgames/.ons_launch; killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer && echo LAUNCHED"))
    time.sleep(9)
    print("进程:", run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    c.close()
finally:
    proxy.terminate()
