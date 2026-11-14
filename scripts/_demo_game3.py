# -*- coding: utf-8 -*-
"""AFC 上传 + SSH 短命令就位（绕开 SSH 大流量/长命令不稳定）"""
import io, os, subprocess, sys, time, paramiko
from PIL import Image
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
GAME = "/var/mobile/Documents/Galgames/TestONS"
SRC_BG = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer\app\GalPlayer\Resources\covers_wide\wide2.jpg"
TMP = os.environ["TEMP"]

# 1. 本地准备
bg = os.path.join(TMP, "bg_small.jpg")
im = Image.open(SRC_BG); im.thumbnail((1280, 720), Image.LANCZOS); im.save(bg, quality=82, optimize=True)

script = """*define
game
*start
bg "bg.jpg",1
^こんにちは、はじめまして。
^这是 GalPlayer 的中文测试行。
^Tap continue / hold skip / two fingers menu
click
end
"""
sp = os.path.join(TMP, "0.txt")
open(sp, "w", encoding="utf-8").write(script)
print("准备:", os.path.getsize(bg), os.path.getsize(sp))

# 2. AFC 上传到 Media/Downloads
for local, name in [(sp, "gp_0.txt"), (bg, "gp_bg.jpg")]:
    r = subprocess.run([sys.executable, "-m", "pymobiledevice3", "afc", "push", local, f"/Downloads/{name}"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("afc push", name, "->", r.returncode, (r.stdout or "")[-80:].strip())

# 3. SSH 短命令搬到位并启动
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
subprocess.run(["taskkill","/F","/IM","iproxy.exe"], capture_output=True); time.sleep(1)
proxy = subprocess.Popen([r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe","-u",UDID,"4494","44"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=4494, username="root", password="alpine", timeout=25,
              allow_agent=False, look_for_keys=False)
    def run(cmd, t=90):
        _,o,e = c.exec_command(P + cmd, timeout=t)
        return (o.read().decode(errors="replace")+e.read().decode(errors="replace")).strip()

    MEDIA = "/var/mobile/Media/Downloads"
    print(run(f"mkdir -p {GAME} && cp -f {MEDIA}/gp_0.txt {GAME}/0.txt && cp -f {MEDIA}/gp_bg.jpg {GAME}/bg.jpg && echo COPY_OK"))
    print(run(f"ls -la {GAME}"))
    print(run(f"chown -R mobile:mobile {GAME} && echo CHOWN_OK"))
    print(run(f"echo {GAME} > /var/mobile/Documents/Galgames/.ons_launch; killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer; echo LAUNCHED"))
    time.sleep(9)
    print("进程:", run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    print("日志尾:", run("tail -6 /var/mobile/Documents/ons_runtime.log"))
    c.close()
finally:
    proxy.terminate()
