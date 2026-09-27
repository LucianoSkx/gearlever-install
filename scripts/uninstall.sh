#!/usr/bin/env bash
set -euo pipefail

# Gear Lever Uninstaller
# Usage: ./uninstall.sh [--yes] [--help]

PREFIX="${PREFIX:-$HOME/.local}"
BASE_DIR="${BASE_DIR:-$HOME/.local/share/gearlever}"
FORCE=0

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'

info()  { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}[warn]${c_reset} %s\n" "$*"; }
die()   { printf "${c_red}[error]${c_reset} %s\n" "$*" >&2; exit 1; }

show_help() {
    cat <<'EOF'
Gear Lever Uninstaller

Usage: curl -fsSL <url> | bash -s -- [options]

Options:
  --yes, -y     Skip confirmation prompt
  -h, --help    Show this help

Environment:
  PREFIX        Install prefix (default: ~/.local)
  BASE_DIR      Build/data directory (default: ~/.local/share/gearlever)
EOF
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --yes|-y) FORCE=1 ;;
        -h|--help) show_help ;;
    esac
done

REMOVE_LIST=(
    "$PREFIX/bin/gearlever"
    "$PREFIX/bin/get_appimage_offset"
    "$PREFIX/share/applications/it.mijorus.gearlever.desktop"
    "$PREFIX/share/metainfo/it.mijorus.gearlever.metainfo.xml"
    "$PREFIX/share/glib-2.0/schemas/it.mijorus.gearlever.gschema.xml"
    "$PREFIX/share/gearlever"
    "$BASE_DIR"
)

echo "This will remove the following files/directories:"
for item in "${REMOVE_LIST[@]}"; do
    [ -e "$item" ] && echo "  - $item"
done

# Icons (detected dynamically)
ICON_FILES=$(find "$PREFIX/share/icons" -name "it.mijorus.gearlever*" -o -name "it.mijorus.smile*" 2>/dev/null || true)
if [ -n "$ICON_FILES" ]; then
    echo "  - Icon files under $PREFIX/share/icons/"
fi

echo

if [ "$FORCE" != "1" ]; then
    read -rp "Are you sure? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || die "aborted"
fi

info "removing gearlever..."

for item in "${REMOVE_LIST[@]}"; do
    if [ -e "$item" ]; then
        rm -rf "$item"
        ok "removed $item"
    else
        info "not found: $item"
    fi
done

# Remove icons
if [ -n "$ICON_FILES" ]; then
    echo "$ICON_FILES" | while read -r icon; do
        [ -n "$icon" ] && rm -f "$icon" && ok "removed $icon"
    done
fi

# Refresh desktop database
if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database -q "$PREFIX/share/applications" 2>/dev/null || true
fi

# Refresh icon cache
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -q -t -f "$PREFIX/share/icons/hicolor" 2>/dev/null || true
fi

printf "\n${c_green}Done!${c_reset} Gear Lever has been uninstalled.\n"
