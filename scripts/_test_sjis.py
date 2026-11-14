# -*- coding: utf-8 -*-
"""用 Shift-JIS(cp932) 编码的测试脚本验证字形渲染（ONS CJK 模式按 SJIS 解析）"""
import io, os, subprocess, sys, time, paramiko, base64
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")

# 日文（SJIS 可编码，字体一定覆盖）+ ASCII 对照
script = """*define
game
*start
bg black,1
`こんにちは　ギャルゲー
`Japanese line 2 OK
`中文测试行
click
end
"""
data = script.encode("cp932", errors="replace")

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

    b64 = base64.b64encode(data).decode()
    print(run(f"echo '{b64}' | base64 -d > /var/mobile/Documents/Galgames/TestONS/0.txt && echo WRITE_OK"))
    print(run("chown mobile:mobile /var/mobile/Documents/Galgames/TestONS/0.txt; wc -c /var/mobile/Documents/Galgames/TestONS/0.txt"))
    print(run("echo /var/mobile/Documents/Galgames/TestONS > /var/mobile/Documents/Galgames/.ons_launch; "
              "killall OnsPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.onsplayer && echo LAUNCHED"))
    time.sleep(8)
    print(run("ps aux | grep -i onsplayer | grep -v grep | wc -l"))
    c.close()
finally:
    proxy.terminate()
