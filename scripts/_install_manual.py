# -*- coding: utf-8 -*-
"""手动安装 GalPlayer：本地解包 .deb -> SFTP 上传 app -> 设备上 ldif 签名 + uicache"""
import io, os, sys, tarfile, subprocess, time

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

DEB = os.path.join(os.environ.get("TEMP", "/tmp"), "com.yg.galplayer_0.1.0_iphoneos-arm64.deb")
WORK = os.path.join(os.environ.get("TEMP", "/tmp"), "gp_deb_extract")
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
HOST_PORT = 4494
PATH_PREFIX = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:"
               "/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")

# ---- 1. 解析 ar 归档，解出 data.tar.gz ----
def ar_members(path):
    with open(path, "rb") as f:
        magic = f.read(8)
        assert magic == b"!<arch>\n", "not an ar archive"
        while True:
            hdr = f.read(60)
            if len(hdr) < 60:
                break
            name = hdr[0:16].decode("ascii", "ignore").strip()
            size = int(hdr[48:58].decode("ascii", "ignore").strip())
            data = f.read(size)
            if size % 2:
                f.read(1)
            yield name.rstrip("/"), data

os.makedirs(WORK, exist_ok=True)
data_tar = None
for name, data in ar_members(DEB):
    print("ar member:", name, len(data))
    if name.startswith("data.tar"):
        data_tar = data
assert data_tar, "data.tar.gz not found"
tar_path = os.path.join(WORK, "data.tar.gz")
open(tar_path, "wb").write(data_tar)

# ---- 2. 解压 app ----
app_root = os.path.join(WORK, "app")
os.makedirs(app_root, exist_ok=True)
with tarfile.open(tar_path, "r:gz") as tf:
    tf.extractall(app_root)
APP_DIR = os.path.join(app_root, "var", "jb", "Applications", "GalPlayer.app")
assert os.path.isdir(APP_DIR), f"app not found: {APP_DIR}"
total = sum(len(files) for _, _, files in os.walk(APP_DIR))
print(f"本地解包完成: {APP_DIR} ({total} 个文件)")

# ---- 3. SFTP 上传 ----
subprocess.run(["taskkill", "/F", "/IM", "iproxy.exe"], capture_output=True)
time.sleep(1)
proxy = subprocess.Popen([IPROXY, "-u", UDID, str(HOST_PORT), "44"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(5)
try:
    import paramiko
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("127.0.0.1", port=HOST_PORT, username="root", password="alpine",
              timeout=25, allow_agent=False, look_for_keys=False)

    def run(cmd, t=600):
        _, o, e = c.exec_command(PATH_PREFIX + cmd, timeout=t)
        return (o.read().decode(errors="replace") + e.read().decode(errors="replace")).strip()

    REMOTE = "/var/jb/Applications/GalPlayer.app"
    print(run(f"rm -rf '{REMOTE}'; mkdir -p /var/jb/Applications && echo PREPARED"))

    sftp = c.open_sftp()
    def ensure_remote_dir(path):
        try:
            sftp.stat(path)
        except IOError:
            ensure_remote_dir(os.path.dirname(path))
            sftp.mkdir(path)

    ensure_remote_dir(REMOTE)
    uploaded = 0
    for dirpath, dirnames, filenames in os.walk(APP_DIR):
        rel = os.path.relpath(dirpath, APP_DIR)
        rdir = REMOTE if rel == "." else os.path.join(REMOTE, rel).replace("\\", "/")
        ensure_remote_dir(rdir)
        for d in dirnames:
            ensure_remote_dir(os.path.join(rdir, d).replace("\\", "/"))
        for fn in filenames:
            lp = os.path.join(dirpath, fn)
            rp = os.path.join(rdir, fn).replace("\\", "/")
            sftp.put(lp, rp)
            uploaded += 1
    sftp.close()
    print(f"SFTP 上传完成: {uploaded} 个文件")

    print("=== 权限 / 签名 / 图标注册 ===")
    print(run(f"chown -R root:wheel '{REMOTE}' && chmod -R 755 '{REMOTE}' && echo PERM_OK"))
    print(run(f"for f in $(find '{REMOTE}' -type f); do ldid -S \"$f\" 2>/dev/null; done; ldid -S '{REMOTE}/GalPlayer'; echo SIGN_OK"))
    print(run(f"uicache -p '{REMOTE}' && echo UICACHE_OK"))
    print(run("ls -la /var/jb/Applications/GalPlayer.app | head -10"))
    print("=== 启动 App ===")
    print(run("uiopen -b com.yg.galplayer && echo OPEN_OK"))
    c.close()
finally:
    proxy.terminate()
