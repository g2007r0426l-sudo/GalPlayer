#!/usr/bin/env bash
# =============================================================================
# ldid 递归签名 —— 主程序 + 全部 Mach-O（Frameworks/ 内每一个都要签）
# 实测教训: 只签主程序 -> 启动即崩，崩溃日志报 mapped file has no cdhash
# 用法: sign.sh /path/to/GalPlayer.app
# =============================================================================
set -euo pipefail
APP="${1:?用法: sign.sh <GalPlayer.app 路径>}"
command -v ldid >/dev/null || { echo "ERROR: 未安装 ldid —— brew install ldid"; exit 1; }
[ -d "$APP" ] || { echo "ERROR: 目录不存在: $APP"; exit 1; }

# 1) 主二进制
ldid -S "$APP/GalPlayer"
echo "[sign] 主程序已签: $APP/GalPlayer"

# 2) Frameworks / PlugIns / 任意子目录中所有 Mach-O（重复签无害）
N=0
while IFS= read -r f; do
    if file "$f" | grep -q "Mach-O"; then
        ldid -S "$f"
        N=$((N+1))
    fi
done < <(find "$APP" -type f)

echo "[sign] 完成: 共签 $((N+1)) 个 Mach-O"
