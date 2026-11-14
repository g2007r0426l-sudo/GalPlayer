# -*- coding: utf-8 -*-
"""从 .deb 安装全部 App 到设备（tar 流式，无需 SFTP/dpkg）"""
import io, os, sys, tarfile, subprocess, time, paramiko, urllib.request, zipfile

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

REPO = "g2007r0426l-sudo/GalPlayer"
WORK = os.path.join(os.environ.get("TEMP", "/tmp"), "gp_install")
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
HOST_PORT = 4494
PATH_PREFIX = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:"
               "/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
os.makedirs(WORK, exist_ok=True)

# ---------- 1. 下载最新 CI 产物 ----------
def gh(path):
    token = open(os.path.join(os.environ["TEMP"], "gh_token.txt")).read().strip()
    req = urllib.request.Request("https://api.github.com" + path,
                                 headers={"Authorization": "Bearer " + token, "User-Agent": "GalPlayer"})
    return urllib.request.urlopen(req, timeout=60).read()

runs = __import__("json").loads(gh(f"/repos/{REPO}/actions/workflows/build.yml/runs?per_page=5"))
run = None
art = None
for cand in runs["workflow_runs"]:
    if cand.get("conclusion") != "success":
        continue
    arts = __import__("json").loads(gh(f"/repos/{REPO}/actions/runs/{cand['id']}/artifacts"))["artifacts"]
    hit = next((a for a in arts if a["name"] == "galplayer-deb"), None)
    if hit:
        run, art = cand, hit
        break
if not art:
    raise SystemExit("没有找到可用的 galplayer-deb 产物")
print(f"[CI] run {run['id']} {run['head_sha'][:7]} {run['conclusion']}")

class NoRedir(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k): return None
try:
    data = urllib.request.build_opener(NoRedir).open(
        urllib.request.Request(f"https://api.github.com/repos/{REPO}/actions/artifacts/{art['id']}/zip",
                               headers={"Authorization": "Bearer " + open(os.path.join(os.environ["TEMP"], "gh_token.txt")).read().strip(),
                                        "User-Agent": "GalPlayer"}), timeout=120).read()
except urllib.error.HTTPError as e:
    data = urllib.request.urlopen(e.headers["Location"], timeout=600).read()

zp = os.path.join(WORK, "art.zip")
open(zp, "wb").write(data)
with zipfile.ZipFile(zp) as z:
    z.extractall(WORK)
debs = [os.path.join(dp, f) for dp, _, fs in os.walk(WORK) for f in fs if f.endswith(".deb")]
deb = max(debs, key=os.path.getmtime)
print(f"[CI] .deb: {deb} ({os.path.getsize(deb)} bytes)")

# ---------- 2. 解 ar -> data.tar.gz -> 解压 ----------
def ar_members(path):
    with open(path, "rb") as f:
        assert f.read(8) == b"!<arch>\n"
        while True:
            hdr = f.read(60)
            if len(hdr) < 60: break
            name = hdr[0:16].decode("ascii", "ignore").strip().rstrip("/")
            size = int(hdr[48:58].decode("ascii", "ignore").strip())
            body = f.read(size)
            if size % 2: f.read(1)
            yield name, body

data_tar = next(b for n, b in ar_members(deb) if n.startswith("data.tar"))
tp = os.path.join(WORK, "data.tar.gz")
open(tp, "wb").write(data_tar)
root = os.path.join(WORK, "root")
if os.path.isdir(root):
    import shutil; shutil.rmtree(root)
os.makedirs(root)
with tarfile.open(tp, "r:gz") as tf:
    tf.extractall(root)

APPS_DIR = os.path.join(root, "var", "jb", "Applications")
apps = [d for d in os.listdir(APPS_DIR) if d.endswith(".app")]
print(f"[deb] 包含 App: {apps}")

# ---------- 3. 打包成 tar 流 ----------
tar_path = os.path.join(WORK, "apps.tar")
with tarfile.open(tar_path, "w") as tf:
    for a in apps:
        tf.add(os.path.join(APPS_DIR, a), arcname=a)
print(f"[tar] {os.path.getsize(tar_path)/1024/1024:.1f} MB")

# ---------- 4. 上传 + 安装 ----------
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

    def run(cmd, t=900):
        _, o, e = c.exec_command(PATH_PREFIX + cmd, timeout=t)
        return (o.read().decode(errors="replace") + e.read().decode(errors="replace")).strip()

    REMOTE = "/var/jb/Applications"
    for a in apps:
        run(f"rm -rf '{REMOTE}/{a}'")
    run(f"mkdir -p '{REMOTE}'")

    stdin, stdout, stderr = c.exec_command(PATH_PREFIX + f"cd '{REMOTE}' && tar xf - && echo UNTAR_OK", timeout=1800)
    with open(tar_path, "rb") as f:
        while True:
            chunk = f.read(256 * 1024)
            if not chunk: break
            stdin.write(chunk); stdin.flush()
    stdin.channel.shutdown_write()
    print("解包:", (stdout.read().decode(errors="replace") + stderr.read().decode(errors="replace")).strip()[:200])

    for a in apps:
        print(run(f"chown -R root:wheel '{REMOTE}/{a}'; chmod -R 755 '{REMOTE}/{a}'; echo PERM_OK_{a}"))
        print(run(f"for f in $(find '{REMOTE}/{a}' -type f); do ldid -S \"$f\" 2>/dev/null; done; echo SIGN_OK_{a}"))
        print(run(f"uicache -p '{REMOTE}/{a}' && echo UICACHE_OK_{a}"))
    print(run(f"ls -la '{REMOTE}'"))
    print(run("killall GalPlayer 2>/dev/null; sleep 1; uiopen -b com.yg.galplayer && echo OPEN_OK"))
    c.close()
finally:
    proxy.terminate()
