# -*- coding: utf-8 -*-
"""验证：游戏 end 后自动回到 GalPlayer"""
import io, os, subprocess, sys, time, paramiko
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
GAME = "/var/mobile/Documents/Galgames/TestONS"
TMP = os.environ["TEMP"]

script = """*define
game
*start
bg "bg.jpg",1
^演示结束，即将返回游戏库…
wait 2500
^已结束
wait 800
end
"""
sp = os.path.join(TMP, "0_exit.txt")
open(sp, "w", encoding="utf-8").write(script)

r = subprocess.run([sys.executable, "-m", "pymobiledevice3", "afc", "push", sp, "/Downloads/gp_0.txt"],
                   capture_output=True, text=True, encoding="utf-8", errors="replace")
print("afc:", r.returncode)

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

    print(run(f"cp -f /var/mobile/Media/Downloads/gp_0.txt {GAME}/0.txt && chown mobile:mobile {GAME}/0.txt && echo COPY_OK"))
    print(run(f"printf '{GAME}\\n0\\n' > /var/mobile/Documents/Galgames/.ons_launch; killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer; echo LAUNCHED"))
    time.sleep(12)
    print("OnsPlayer 进程数:", run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    print("GalPlayer 进程数:", run("ps aux | grep -i galplayer | grep -v grep | wc -l"))
    print("日志尾:", run("tail -3 /var/mobile/Documents/ons_runtime.log"))
    c.close()
finally:
    proxy.terminate()
