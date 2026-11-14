#!/usr/bin/env bash
# =============================================================================
# ldid recursive signing: main binary + every Mach-O inside the bundle
#
# Lessons learned on real device:
#   - signing only the main binary -> crash on launch ("mapped file has no cdhash")
#   - entitlements matter: without platform-application the process may be
#     denied GPU (metal) access on some jailbreak setups
#
# usage: sign.sh /path/to/SomeApp.app
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENT="$ROOT_DIR/packaging/entitlements.plist"
APP="${1:?usage: sign.sh <App.app path>}"

command -v ldid >/dev/null || { echo "[sign] ERROR: ldid not installed"; exit 1; }
[ -d "$APP" ] || { echo "[sign] ERROR: no such dir: $APP"; exit 1; }

sign_one() {
    local f="$1"
    [ -f "$f" ] || return 0
    if [ -f "$ENT" ]; then
        ldid -S"$ENT" "$f" 2>/dev/null && return 0
    fi
    ldid -S "$f" 2>/dev/null
}

# 1) main binary: guess from bundle name, then fall back to CFBundleExecutable
BIN="$APP/$(basename "$APP" .app)"
if [ ! -f "$BIN" ] && [ -x /usr/libexec/PlistBuddy ]; then
    EXEC=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Info.plist" 2>/dev/null | tr -d '\r')
    [ -n "${EXEC:-}" ] && [ -f "$APP/$EXEC" ] && BIN="$APP/$EXEC"
fi
if [ -f "$BIN" ]; then
    sign_one "$BIN"
    echo "[sign] main binary signed: $BIN"
else
    echo "[sign] WARN: main binary not found in $APP"
fi

# 2) every Mach-O inside (idempotent; per-file failures do not abort)
N=0
while IFS= read -r f; do
    [ -f "$f" ] || continue
    if file "$f" 2>/dev/null | grep -q "Mach-O"; then
        sign_one "$f" && N=$((N+1))
    fi
done < <(find "$APP" -type f 2>/dev/null)

echo "[sign] done: $N Mach-O files -> ${APP}"
