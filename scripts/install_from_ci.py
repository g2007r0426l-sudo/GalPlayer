# -*- coding: utf-8 -*-
"""
install_from_ci.py — 从 GitHub Actions 下载最新成功的 GalPlayer .deb 并自动装入越狱 iPad
用法: python scripts/install_from_ci.py [run_id]   （缺省 = 最新成功运行）
依赖: Python + paramiko（Windows 本机即可，iPad 通过 USB 连接）
"""
import io, json, os, sys, time, zipfile, subprocess, urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

REPO   = "g2007r0426l-sudo/GalPlayer"
UDID   = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
TOKEN_FILE = os.path.join(os.environ.get("TEMP", "/tmp"), "gh_token.txt")
BUNDLE_ID  = "com.yg.galplayer"

def api(url, headers=None):
    req = urllib.request.Request(url, headers=headers or {})
    return urllib.request.urlopen(req, timeout=120)

def download_artifact(url, headers):
    """GitHub 产物下载会 302 到 Azure 存储；重定向后必须去掉 Authorization 头"""
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, hdrs, newurl):
            return None
    opener = urllib.request.build_opener(NoRedirect)
    try:
        return opener.open(urllib.request.Request(url, headers=headers), timeout=120).read()
    except urllib.error.HTTPError as e:
        if e.code in (301, 302, 303, 307, 308):
            loc = e.headers.get("Location")
            return urllib.request.urlopen(loc, timeout=600).read()
        raise

# 1) 找到目标运行
token = open(TOKEN_FILE).read().strip()
H = {"Authorization": f"Bearer {token}", "User-Agent": "GalPlayerBuilder"}
if len(sys.argv) > 1:
    run_id = sys.argv[1]
else:
    runs = json.load(api(f"https://api.github.com/repos/{REPO}/actions/workflows/build.yml/runs?per_page=20", H))["workflow_runs"]
    ok = [r for r in runs if r["conclusion"] == "success"]
    if not ok:
        print("没有成功的构建运行"); sys.exit(1)
    run_id = ok[0]["id"]
print(f"[CI] 目标运行: {run_id}")

# 2) 下载 galplayer-deb 产物
arts = json.load(api(f"https://api.github.com/repos/{REPO}/actions/runs/{run_id}/artifacts", H))["artifacts"]
art = next((a for a in arts if a["name"] == "galplayer-deb"), None)
if not art:
    print("产物 galplayer-deb 不存在"); sys.exit(1)
print(f"[CI] 下载产物 {art['size_in_bytes']:,} bytes ...")
zip_data = download_artifact(f"https://api.github.com/repos/{REPO}/actions/artifacts/{art['id']}/zip", H)
zf = zipfile.ZipFile(io.BytesIO(zip_data))
deb_names = [n for n in zf.namelist() if n.endswith(".deb")]
if not deb_names:
    print("zip 里没有 .deb:", zf.namelist()); sys.exit(1)
deb_path = os.path.join(os.environ.get("TEMP", "/tmp"), deb_names[0])
with open(deb_path, "wb") as f:
    f.write(zf.read(deb_names[0]))
print(f"[CI] .deb 就绪: {deb_path} ({os.path.getsize(deb_path):,} bytes)")

# 3) 推送进 iPad 并安装
proxy = subprocess.Popen([IPROXY, "-u", UDID, "4444", "44"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(4)
try:
    import paramiko
    c = paramiko.SSHClient(); c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=4444, username="root", password="alpine", timeout=20,
              allow_agent=False, look_for_keys=False)
    sftp = c.open_sftp()
    sftp.put(deb_path, "/var/mobile/Documents/GalPlayer.deb")
    sftp.close()
    print("[设备] .deb 已推送")

    def run(cmd, t=300):
        _, o, e = c.exec_command(cmd, timeout=t)
        out = o.read().decode(errors="replace") + e.read().decode(errors="replace")
        return out

    print("[设备] dpkg -i ...")
    print(run("dpkg -i /var/mobile/Documents/GalPlayer.deb; echo DPKG_EXIT=$?"))
    print(run("uicache -p /var/jb/Applications/GalPlayer.app && echo UICACHE_OK"))
    print(run(f"uiopen -b {BUNDLE_ID} && echo OPEN_OK"))
    c.close()
finally:
    proxy.terminate()

print("[完成] GalPlayer 应已启动。截图验证请运行 pymobiledevice3 截屏。")
