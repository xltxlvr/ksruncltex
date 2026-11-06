#!/bin/sh
# ---------------------------------------------------------------------------
# ksruncltex installer (macOS / Linux, TeX Live or MiKTeX)
#
# Usage:
#   sh install.sh               : Install ksruncltex
#   sh install.sh --uninstall   : Remove existing ksruncltex installation
#   sh install.sh --reinstall   : Remove and then cleanly install again
# ---------------------------------------------------------------------------
set -eu

info()  { printf '[Info] %s\n' "$1"; }
warn()  { printf '[Warning] %s\n' "$1" >&2; }
die()   { printf '[Error] %s\n' "$1" >&2; exit 1; }

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RES_DIR="$SCRIPT_DIR/Resources"

DO_UNINSTALL=0
DO_INSTALL=1
if [ "${1:-}" = "--uninstall" ]; then
    DO_UNINSTALL=1
    DO_INSTALL=0
elif [ "${1:-}" = "--reinstall" ]; then
    DO_UNINSTALL=1
    DO_INSTALL=1
fi

# --- Cleanup: remove legacy cluttex_patched.lua (no longer needed) ---------
LEGACY_LUA=$(kpsewhich --format=lua cluttex_patched.lua 2>/dev/null || true)
if [ -n "$LEGACY_LUA" ] && [ -f "$LEGACY_LUA" ]; then
    rm -f "$LEGACY_LUA"
    info "Removed legacy file: $LEGACY_LUA"
fi

# --- 0. Uninstall Logic ----------------------------------------------------
if [ "$DO_UNINSTALL" -eq 1 ]; then
    info "Uninstalling ksruncltex..."

    EXISTING_LUA=$(kpsewhich --format=lua ksruncltex.lua 2>/dev/null || true)
    if [ -n "$EXISTING_LUA" ] && [ -f "$EXISTING_LUA" ]; then
        rm -f "$EXISTING_LUA"
        info "Removed: $EXISTING_LUA"
    fi

    EXISTING_LAUNCHER=$(command -v ksruncltex 2>/dev/null || true)
    if [ -n "$EXISTING_LAUNCHER" ] && [ -f "$EXISTING_LAUNCHER" ]; then
        rm -f "$EXISTING_LAUNCHER"
        info "Removed: $EXISTING_LAUNCHER"
    fi

    ENGINE_PATH="$HOME/Library/TeXShop/Engines/ksRunCluttex.engine"
    if [ -f "$ENGINE_PATH" ]; then
        rm -f "$ENGINE_PATH"
        info "Removed: $ENGINE_PATH"
    fi

    if command -v mktexlsr >/dev/null 2>&1; then
        mktexlsr >/dev/null 2>&1 || true
    elif command -v initexmf >/dev/null 2>&1; then
        initexmf --update-fndb >/dev/null 2>&1 || true
    fi

    if [ "$DO_INSTALL" -eq 0 ]; then
        info "Uninstall complete."
        exit 0
    fi
    echo
fi

# --- 1. Preconditions: a TeX distribution must already be installed --------
command -v kpsewhich >/dev/null 2>&1 || die "kpsewhich를 찾을 수 없습니다."
command -v texlua    >/dev/null 2>&1 || die "texlua를 찾을 수 없습니다."

for f in ksruncltex.lua ksruncltex.bat; do
    [ -f "$RES_DIR/$f" ] || die "Resources/$f 파일을 찾을 수 없습니다."
done

# --- 2. Install dir for the Lua scripts ------------------------------------
DEST=""
EXISTING_LUA=$(kpsewhich --format=lua ksruncltex.lua 2>/dev/null || true)
if [ -n "$EXISTING_LUA" ]; then
    EXISTING_DIR=$(CDPATH= cd -- "$(dirname -- "$EXISTING_LUA")" 2>/dev/null && pwd || true)
    if [ -n "$EXISTING_DIR" ] && [ -w "$EXISTING_DIR" ]; then
        DEST="$EXISTING_DIR"
        info "기존 설치를 감지했습니다 ($EXISTING_LUA) - 해당 위치를 업데이트합니다."
    else
        warn "기존 설치($EXISTING_LUA)가 감지되었지만 쓰기 권한이 없습니다."
    fi
fi

if [ -z "$DEST" ]; then
    TEXMFHOME=$(kpsewhich --var-value=TEXMFHOME 2>/dev/null || true)
    if [ -z "$TEXMFHOME" ]; then
        warn "kpsewhich가 TEXMFHOME 값을 반환하지 않았습니다. 자체 TEXMF 루트를 등록합니다..."
        TEXMFHOME="${XDG_DATA_HOME:-$HOME/.local/share}/ksruncltex/texmf"
        mkdir -p "$TEXMFHOME"
        if command -v initexmf >/dev/null 2>&1; then
            if initexmf --register-root="$TEXMFHOME" >/dev/null 2>&1; then
                info "$TEXMFHOME 를 새 TEXMF 루트로 등록했습니다."
            else
                die "'initexmf --register-root' 실행에 실패했습니다."
            fi
        else
            die "TEXMFHOME을 확인할 수 없고 initexmf도 찾을 수 없어 자동 등록이 불가능합니다."
        fi
    fi
    DEST="$TEXMFHOME/scripts/ksruncltex"
fi

mkdir -p "$DEST"
cp "$RES_DIR/ksruncltex.lua" "$DEST/"
info "ksruncltex.lua를 설치했습니다: $DEST"

# --- 3. Refresh the filename database --------------------------------------
if command -v mktexlsr >/dev/null 2>&1; then
    if mktexlsr >/dev/null 2>&1; then
        info "mktexlsr 실행 완료"
    fi
elif command -v initexmf >/dev/null 2>&1; then
    if initexmf --update-fndb >/dev/null 2>&1; then
        info "initexmf --update-fndb 실행 완료"
    fi
fi

# --- 4. Install a ksruncltex command-line launcher -------------------------
write_launcher() {
    cat > "$1" <<'EOF'
#!/bin/sh
LUA_SCRIPT=$(kpsewhich --format=lua ksruncltex.lua)
if [ -z "$LUA_SCRIPT" ]; then
    echo "[Error] ksruncltex.lua를 찾을 수 없습니다." >&2
    exit 1
fi
exec texlua "$LUA_SCRIPT" "$@"
EOF
    chmod +x "$1"
}

EXISTING_LAUNCHER=$(command -v ksruncltex 2>/dev/null || true)
if [ -n "$EXISTING_LAUNCHER" ] && [ -w "$EXISTING_LAUNCHER" ]; then
    write_launcher "$EXISTING_LAUNCHER"
    info "기존 명령행 런처를 업데이트했습니다: ksruncltex ($EXISTING_LAUNCHER)"
else
    BIN_DIR=$(kpsewhich --var-value=SELFAUTOLOC 2>/dev/null || true)
    if [ -n "$BIN_DIR" ] && [ -w "$BIN_DIR" ]; then
        LAUNCHER="$BIN_DIR/ksruncltex"
        write_launcher "$LAUNCHER"
        info "명령행 런처를 설치했습니다: ksruncltex ($LAUNCHER)"
    else
        warn "TeX bin 폴더에 쓰기 권한이 없어 'ksruncltex' 명령을 설치하지 못했습니다."
    fi
fi

# --- 5. macOS + TeXShop engine ---------------------------------------------
if [ "$(uname -s 2>/dev/null || echo unknown)" = "Darwin" ] && [ -f "$RES_DIR/ksRunCluttex.engine" ]; then
    if [ -d "$HOME/Library/TeXShop" ]; then
        ENGINE_DIR="$HOME/Library/TeXShop/Engines"
        mkdir -p "$ENGINE_DIR"
        cp "$RES_DIR/ksRunCluttex.engine" "$ENGINE_DIR/"
        chmod +x "$ENGINE_DIR/ksRunCluttex.engine"
        info "TeXShop 엔진을 설치했습니다: $ENGINE_DIR/ksRunCluttex.engine"
    fi
fi

echo
info "설치가 완료되었습니다."
