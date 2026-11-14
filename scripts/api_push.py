# -*- coding: utf-8 -*-
"""用 GitHub API 直接提交（git 协议被墙时的兜底）"""
import base64, json, os, subprocess, sys, urllib.request

sys.stdout = __import__("io").TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
ROOT = r"D:\AA下载文件其他别乱动\Deepseek听话\GalPlayer"
REPO = "g2007r0426l-sudo/GalPlayer"
BASE = sys.argv[1] if len(sys.argv) > 1 else "HEAD~1"
TOKEN = open(os.path.join(os.environ["TEMP"], "gh_token.txt")).read().strip()

def api(path, method="GET", payload=None):
    url = "https://api.github.com" + path
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": "Bearer " + TOKEN,
        "User-Agent": "GalPlayer",
        "Content-Type": "application/json",
    })
    return json.loads(urllib.request.urlopen(req, timeout=120).read().decode())

# 1. 变更列表
diff = subprocess.run(["git", "-C", ROOT, "diff", "--name-status", BASE, "HEAD"],
                      capture_output=True, text=True, encoding="utf-8").stdout.strip().splitlines()
changes = []
for line in diff:
    parts = line.split("\t")
    if len(parts) < 2:
        continue
    status, path = parts[0], parts[-1]
    changes.append((status[0], path))
print(f"变更 {len(changes)} 个文件")

ref = api(f"/repos/{REPO}/git/ref/heads/main")
head = ref["object"]["sha"]
base_commit = api(f"/repos/{REPO}/git/commits/{head}")
print("远端 HEAD:", head[:7])

# 2. 上传 blob
entries = []
for status, path in changes:
    full = os.path.join(ROOT, path)
    if status == "D":
        entries.append({"path": path.replace("\\", "/"), "mode": "100644", "sha": None})
        print("  D", path)
        continue
    raw = open(full, "rb").read()
    blob = api(f"/repos/{REPO}/git/blobs", "POST", {
        "content": base64.b64encode(raw).decode(),
        "encoding": "base64",
    })
    mode = "100755" if os.access(full, os.X_OK) and not path.lower().endswith((".png", ".jpg", ".plist", ".ttf", ".yml", ".md", ".swift")) else "100644"
    entries.append({"path": path.replace("\\", "/"), "mode": mode, "sha": blob["sha"]})
    print(f"  {status} {path} ({len(raw)}B)")

# 3. tree + commit
tree = api(f"/repos/{REPO}/git/trees", "POST", {"base_tree": base_commit["tree"]["sha"], "tree": entries})
msg = subprocess.run(["git", "-C", ROOT, "log", "-1", "--pretty=%B"], capture_output=True, text=True,
                     encoding="utf-8").stdout.strip()
commit = api(f"/repos/{REPO}/git/commits", "POST", {
    "message": msg, "tree": tree["sha"], "parents": [head],
})
print("新 commit:", commit["sha"][:7])
api(f"/repos/{REPO}/git/refs/heads/main", "PATCH", {"sha": commit["sha"], "force": False})
print("✅ 远端 main 已更新")

# 4. 让本地也认为同步
subprocess.run(["git", "-C", ROOT, "fetch", "origin", "main"], capture_output=True)
