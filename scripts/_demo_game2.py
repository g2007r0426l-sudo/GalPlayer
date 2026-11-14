# -*- coding: utf-8 -*-
"""分块上传演示游戏资源（避免命令行过长）"""
import io, os, subprocess, sys, time, paramiko, base64
from PIL import Image
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
GAME = "/var/mobile/Documents/Galgames/TestONS"
SRC_BG = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer\app\GalPlayer\Resources\covers_wide\wide2.jpg"

# 1) 缩小背景图
tmp = os.path.join(os.environ["TEMP"], "bg_small.jpg")
im = Image.open(SRC_BG); im.thumbnail((1280, 720), Image.LANCZOS)
im.save(tmp, quality=82, optimize=True)
print("bg:", os.path.getsize(tmp), "bytes")

script = """*define
game
*start
bg "bg.jpg",1
^こんにちは、はじめまして。
^这是 GalPlayer 的中文测试行。
^Tap to continue / long press to skip / two fingers for menu
click
end
""".encode("utf-8")

def push_chunks(run, b64, remote, chunk=20000):
    run(f"rm -f {remote}; : > {remote}")
    for i in range(0, len(b64), chunk):
        part = b64[i:i+chunk]
        run(f"echo '{part}' | base64 -d >> {remote}")

subprocess.run(["taskkill","/F","/IM","iproxy.exe"], capture_output=True); time.sleep(1)
proxy = subprocess.Popen([IPROXY,"-u",UDID,"4494","44"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=4494, username="root", password="alpine", timeout=25,
              allow_agent=False, look_for_keys=False)
    def run(cmd, t=120):
        _,o,e = c.exec_command(P + cmd, timeout=t)
        return (o.read().decode(errors="replace")+e.read().decode(errors="replace")).strip()

    run(f"mkdir -p {GAME}")
    push_chunks(run, base64.b64encode(script).decode(), f"{GAME}/0.txt")
    push_chunks(run, base64.b64encode(open(tmp,"rb").read()).decode(), f"{GAME}/bg.jpg")
    print(run(f"ls -la {GAME}"))
    print(run(f"head -c 120 {GAME}/0.txt; echo; file {GAME}/bg.jpg"))
    print(run(f"chown -R mobile:mobile {GAME}"))
    print(run(f"echo {GAME} > /var/mobile/Documents/Galgames/.ons_launch; killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer; echo LAUNCHED"))
    time.sleep(9)
    print("进程:", run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    c.close()
finally:
    proxy.terminate()
