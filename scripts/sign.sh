#!/usr/bin/env bash
# =============================================================================
# ldid 递归签名 —— 主程序 + 全部 Mach-O（Frameworks/ 内每一个都要签）
# 实测教训: 只签主程序 -> 启动即崩，崩溃日志报 mapped file has no cdhash
#
# 用法: sign.sh /path/to/SomeApp.app
#       主二进制名自动从 Info.plist 的 CFBundleExecutable 读取（不硬编码）
# =============================================================================
set -uo pipefail

APP="${1:?用法: sign.sh <App.app 路径>}"
command -v ldid >/dev/null || { echo "[sign] ERROR: 未安装 ldid —— brew install ldid"; exit 1; }
[ -d "$APP" ] || { echo "[sign] ERROR: 目录不存在: $APP"; exit 1; }

# 1) 主二进制：先按 .app 目录名猜，再查 Info.plist
BIN="$APP/$(basename "$APP" .app)"
if [ ! -f "$BIN" ]; then
    PB=/usr/libexec/PlistBuddy
    if [ -x "$PB" ]; then
        EXEC=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Info.plist" 2>/dev/null | tr -d '\r')
        [ -n "${EXEC:-}" ] && [ -f "$APP/$EXEC" ] && BIN="$APP/$EXEC"
    fi
fi

if [ -f "$BIN" ]; then
    ldid -S "$BIN" || echo "[sign] WARN: 主程序签名失败: $BIN"
    echo "[sign] 主程序已签: $BIN"
else
    echo "[sign] WARN: 未找到主程序（跳过）: $APP"
fi

# 2) 所有子文件中真正的 Mach-O（重复签无害，单个失败不影响整体）
N=0
while IFS= read -r f; do
    [ -f "$f" ] || continue
    if file "$f" 2>/dev/null | grep -q "Mach-O"; then
        ldid -S "$f" 2>/dev/null && N=$((N+1))
    fi
done < <(find "$APP" -type f 2>/dev/null)

echo "[sign] 完成: 共签 $((N+1)) 个 Mach-O（$APP）"
