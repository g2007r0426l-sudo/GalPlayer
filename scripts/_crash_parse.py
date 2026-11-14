# -*- coding: utf-8 -*-
"""把 OnsPlayer 崩溃日志拉到本地解析线程回溯"""
import io, os, sys, subprocess, time, paramiko, json
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
P = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:/var/jb/bin:"
     "/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
LOCAL = r"D:\iPad-JB-logs\OnsPlayer.ips"

subprocess.run(["taskkill","/F","/IM","iproxy.exe"], capture_output=True); time.sleep(1)
proxy = subprocess.Popen([IPROXY,"-u",UDID,"4494","44"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=4494, username="root", password="alpine", timeout=25,
              allow_agent=False, look_for_keys=False)
    sftp_fail = False
    cmd = ("f=$(ls -t /var/mobile/Library/Logs/CrashReporter/*OnsPlayer*.ips 2>/dev/null | head -1); "
           "base64 \"$f\"")
    _, o, e = c.exec_command(P + cmd, timeout=120)
    b64 = o.read().decode()
    import base64 as b64mod
    raw = b64mod.b64decode("".join(b64.split()))
    open(LOCAL, "wb").write(raw)
    print("已保存", LOCAL, len(raw), "bytes")
    c.close()
finally:
    proxy.terminate()

txt = open(LOCAL, "r", encoding="utf-8", errors="replace").read()
# ips: 第一行是 header JSON，其后是主体 JSON
first_nl = txt.find("\n")
body = txt[first_nl+1:]
data = json.loads(body)
imgs = data.get("usedImages", [])
def img_name(i):
    try:
        im = imgs[i]
        return im.get("name") or im.get("path", "?").split("/")[-1]
    except Exception:
        return f"img{i}"

print("\n=== 崩溃线程 ===")
ft = data.get("faultingThread", 0)
for idx, th in enumerate(data.get("threads", [])):
    if idx != ft: continue
    print("queue:", th.get("queue"))
    for fr in th.get("frames", [])[:28]:
        sym = fr.get("symbol") or f"0x{fr.get('imageOffset',0):x}"
        print(f"  {img_name(fr.get('imageIndex',-1)):34s} {sym}")

print("\n=== lastExceptionBacktrace ===")
for fr in (data.get("lastExceptionBacktrace") or [])[:20]:
    sym = fr.get("symbol") or f"0x{fr.get('imageOffset',0):x}"
    print(f"  {img_name(fr.get('imageIndex',-1)):34s} {sym}")
