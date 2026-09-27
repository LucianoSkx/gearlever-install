#!/usr/bin/env bash
set -euo pipefail

# Gear Lever Installer (source build)
# Usage: ./install.sh [--skip-deps] [--verbose] [--prefix=DIR] [--help]

PREFIX="${PREFIX:-$HOME/.local}"
BASE_DIR="${BASE_DIR:-$HOME/.local/share/gearlever}"
SOURCE_DIR="$BASE_DIR/src"
VENV_DIR="$BASE_DIR/venv"
BUILD_DIR="$SOURCE_DIR/build"
GEARLEVER_REPO="https://github.com/mijorus/gearlever.git"
BRANCH="${BRANCH:-master}"
SKIP_DEPS="${GEARLEVER_INSTALL_SKIP_DEPS:-0}"
VERBOSE="${VERBOSE:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'

info()  { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}[warn]${c_reset} %s\n" "$*"; }
die()   { printf "${c_red}[error]${c_reset} %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "command not found: $1"; }

# Silent by default, verbose with VERBOSE=1
run_cmd() {
    if [ "$VERBOSE" = "1" ]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

show_help() {
    cat <<'EOF'
Gear Lever Installer (source build)

Usage: curl -fsSL <url> | bash -s -- [options]

Options:
  --skip-deps       Skip system dependency installation
  --verbose         Show all command output
  --prefix=DIR      Install prefix (default: ~/.local)
  --branch=BRANCH   Git branch to build (default: master)
  -h, --help        Show this help

Environment:
  PREFIX            Install prefix
  BASE_DIR          Build/data directory
  GEARLEVER_INSTALL_SKIP_DEPS=1   Same as --skip-deps
  VERBOSE=1         Same as --verbose
EOF
    exit 0
}

# Parse arguments (also passed via stdin from curl | bash -s --)
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --verbose) VERBOSE=1 ;;
        --prefix=*) PREFIX="${arg#*=}" ;;
        --branch=*) BRANCH="${arg#*=}" ;;
        -h|--help) show_help ;;
    esac
done

detect_pkg_manager() {
    if   command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf    >/dev/null 2>&1; then echo dnf
    else die "unsupported distro (use Arch, Debian/Ubuntu or Fedora)"
    fi
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

install_deps() {
    local pm
    pm="$(detect_pkg_manager)"
    info "installing system dependencies via $pm..."
    case "$pm" in
        pacman)
            $SUDO pacman -S --noconfirm --needed \
                meson ninja python python-pip python-gobject \
                gtk4 libadwaita glib2 7zip squashfs-tools desktop-file-utils \
                gettext gobject-introspection gcc dbus
            ;;
        apt)
            $SUDO apt-get update
            $SUDO apt-get install -y \
                meson ninja-build python3 python3-pip python3-venv python3-gi \
                python3-gi-cairo gir1.2-gtk-4.0 gir1.2-adw-1 libadwaita-1-dev \
                libgtk-4-dev 7zip squashfs-tools desktop-file-utils gettext \
                libgirepository1.0-dev gcc python3-dev libdbus-1-dev
            ;;
        dnf)
            $SUDO dnf install -y \
                meson ninja-build python3 python3-pip python3-gobject \
                gtk4 libadwaita p7zip squashfs-tools desktop-file-utils \
                gettext gobject-introspection-devel gcc python3-devel dbus-devel
            ;;
    esac
    ok "dependencies installed"
}

setup_source() {
    if [ -d "$SOURCE_DIR/.git" ]; then
        info "updating source at $SOURCE_DIR..."
        git -C "$SOURCE_DIR" pull --ff-only --rebase=false origin "$BRANCH" \
            || warn "git pull failed; continuing with current source"
    else
        info "cloning gearlever ($BRANCH)..."
        mkdir -p "$BASE_DIR"
        git clone --depth 1 --branch "$BRANCH" "$GEARLEVER_REPO" "$SOURCE_DIR"
    fi
    ok "source ready"
}

setup_venv() {
    need_cmd python3
    if [ ! -x "$VENV_DIR/bin/python" ]; then
        info "creating venv..."
        python3 -m venv --system-site-packages "$VENV_DIR" || die "failed to create venv"
    fi
    info "installing python dependencies (pip)..."
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    if [ -f "$SOURCE_DIR/requirements.txt" ]; then
        "$VENV_DIR/bin/pip" install --quiet -r "$SOURCE_DIR/requirements.txt"
    fi
    ok "venv ready"
}

build_app() {
    need_cmd meson
    need_cmd ninja
    export PATH="$VENV_DIR/bin:$PATH"
    cd "$SOURCE_DIR"

    if [ -d "$BUILD_DIR" ]; then
        info "reconfiguring build..."
        meson setup --reconfigure "$BUILD_DIR" --prefix "$PREFIX"
    else
        info "configuring build..."
        meson setup "$BUILD_DIR" --prefix "$PREFIX"
    fi

    info "compiling..."
    ninja -C "$BUILD_DIR"

    info "installing to $PREFIX..."
    if ! meson install -C "$BUILD_DIR" >/dev/null 2>&1; then
        warn "meson install had issues; continuing with manual copy"
    fi

    mkdir -p "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/metainfo" "$PREFIX/share/glib-2.0/schemas"

    if [ -f "$BUILD_DIR/src/gearlever" ]; then
        cp "$BUILD_DIR/src/gearlever" "$PREFIX/bin/gearlever"
        chmod +x "$PREFIX/bin/gearlever"
    else
        die "compiled binary not found in $BUILD_DIR/src/"
    fi

    # Install .desktop with absolute Exec path (fix for KDE/Plasma PATH issue)
    if [ -f "$BUILD_DIR/data/it.mijorus.gearlever.desktop" ]; then
        local desktop_file="$BUILD_DIR/data/it.mijorus.gearlever.desktop"
        sed -i "s|^Exec=gearlever|Exec=$PREFIX/bin/gearlever|" "$desktop_file"
        cp "$desktop_file" "$PREFIX/share/applications/"
        chmod +x "$PREFIX/share/applications/it.mijorus.gearlever.desktop"
    fi

    [ -f "$BUILD_DIR/data/it.mijorus.gearlever.metainfo.xml" ] && cp "$BUILD_DIR/data/it.mijorus.gearlever.metainfo.xml" "$PREFIX/share/metainfo/"
    [ -f "$SOURCE_DIR/data/it.mijorus.gearlever.gschema.xml" ] && cp "$SOURCE_DIR/data/it.mijorus.gearlever.gschema.xml" "$PREFIX/share/glib-2.0/schemas/"

    if command -v glib-compile-schemas >/dev/null 2>&1; then
        glib-compile-schemas "$PREFIX/share/glib-2.0/schemas" >/dev/null || true
    fi

    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database -q "$PREFIX/share/applications" 2>/dev/null || true
    fi

    if [ -f "$SOURCE_DIR/build-aux/get_appimage_offset.sh" ]; then
        cp "$SOURCE_DIR/build-aux/get_appimage_offset.sh" "$PREFIX/bin/get_appimage_offset"
        chmod +x "$PREFIX/bin/get_appimage_offset"
    fi

    ok "build installed"
}

verify() {
    if [ ! -x "$PREFIX/bin/gearlever" ]; then
        die "gearlever binary not found at $PREFIX/bin/gearlever"
    fi

    local ver
    ver="$(grep -A1 "project('gearlever'" "$SOURCE_DIR/meson.build" | grep -oE "version: '[^']+'" | grep -oE "[0-9.]+" || echo "?")"

    if [ -f "$PREFIX/share/applications/it.mijorus.gearlever.desktop" ]; then
        if command -v desktop-file-validate >/dev/null 2>&1; then
            desktop-file-validate "$PREFIX/share/applications/it.mijorus.gearlever.desktop" >/dev/null \
                || warn ".desktop file has validation warnings"
        fi
    fi

    ok "gearlever $ver installed and working"
}

main() {
    info "Gear Lever installer (source build)"
    need_cmd git
    if [ "$SKIP_DEPS" != "1" ]; then
        install_deps
    fi
    setup_source
    setup_venv
    build_app
    verify

    if [[ ":$PATH:" != *":$PREFIX/bin:"* ]]; then
        warn "$PREFIX/bin is not in your PATH."
        if [[ "$SHELL" == */fish ]]; then
            echo "  Add it permanently running: fish_add_path $PREFIX/bin"
        else
            echo "  Add it permanently running: export PATH=\"$PREFIX/bin:\$PATH\""
        fi
    fi

    printf "\n${c_green}Done!${c_reset} Run: gearlever\n"
    echo "  Binary:  $PREFIX/bin/gearlever"
    echo "  Desktop: $PREFIX/share/applications/it.mijorus.gearlever.desktop"
}

main "$@"
