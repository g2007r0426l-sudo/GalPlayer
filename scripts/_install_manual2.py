# -*- coding: utf-8 -*-
"""手动安装 GalPlayer 第2版：tar 流式上传（无需 SFTP/sftp-server）"""
import io, os, sys, tarfile, subprocess, time, paramiko

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

WORK = os.path.join(os.environ.get("TEMP", "/tmp"), "gp_deb_extract")
APP_DIR = os.path.join(WORK, "app", "var", "jb", "Applications", "GalPlayer.app")
IPROXY = r"D:\iPad-JB\tools\libimobiledevice\iproxy.exe"
UDID = "0a6e72b6a29042f0d2d2177a4fbaefbd48c6a802"
HOST_PORT = 4494
PATH_PREFIX = ("export PATH=/cores/binpack/sbin:/cores/binpack/usr/bin:/var/jb/usr/bin:"
               "/var/jb/bin:/var/jb/usr/sbin:/var/jb/sbin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH; ")
REMOTE = "/var/jb/Applications"

assert os.path.isdir(APP_DIR), f"missing {APP_DIR}"

# ---- 1. 本地打 tar（无压缩，避免设备 gzip 依赖） ----
tar_path = os.path.join(WORK, "app.tar")
with tarfile.open(tar_path, "w") as tf:
    tf.add(APP_DIR, arcname="GalPlayer.app")
size = os.path.getsize(tar_path)
print(f"tar 包: {tar_path} ({size/1024/1024:.1f} MB)")

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

    print(run(f"rm -rf '{REMOTE}/GalPlayer.app'; mkdir -p '{REMOTE}'; echo PREPARED"))

    # ---- 2. tar 流式上传 + 设备解包 ----
    stdin, stdout, stderr = c.exec_command(
        PATH_PREFIX + f"cd '{REMOTE}' && tar xf - && echo UNTAR_OK", timeout=1800)
    with open(tar_path, "rb") as f:
        while True:
            chunk = f.read(256 * 1024)
            if not chunk:
                break
            stdin.write(chunk)
            stdin.flush()
    stdin.channel.shutdown_write()
    out = stdout.read().decode(errors="replace")
    err = stderr.read().decode(errors="replace")
    print("解包输出:", (out + err).strip()[:500])

    # ---- 3. 权限 / 签名 / 注册 / 启动 ----
    print(run(f"chown -R root:wheel '{REMOTE}/GalPlayer.app' && chmod -R 755 '{REMOTE}/GalPlayer.app' && echo PERM_OK"))
    print(run(f"for f in $(find '{REMOTE}/GalPlayer.app' -type f); do ldid -S \"$f\" 2>/dev/null; done; ldid -S '{REMOTE}/GalPlayer.app/GalPlayer'; echo SIGN_OK"))
    print(run(f"uicache -p '{REMOTE}/GalPlayer.app' && echo UICACHE_OK"))
    print(run(f"ls -la '{REMOTE}/GalPlayer.app' | head -12"))
    print(run("uiopen -b com.yg.galplayer && echo OPEN_OK"))
    c.close()
finally:
    proxy.terminate()
