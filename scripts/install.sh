#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
BASE_DIR="${BASE_DIR:-$HOME/.local/share/gearlever}"
SOURCE_DIR="$BASE_DIR/src"
VENV_DIR="$BASE_DIR/venv"
BUILD_DIR="$SOURCE_DIR/build"
GEARLEVER_REPO="https://github.com/mijorus/gearlever.git"
BRANCH="${BRANCH:-master}"
SKIP_DEPS="${GEARLEVER_INSTALL_SKIP_DEPS:-0}"

c_reset='\033[0m'; c_green='\033[1;32m'; c_yellow='\033[1;33m'; c_red='\033[1;31m'; c_cyan='\033[1;36m'

info()  { printf "${c_cyan}[info]${c_reset} %s\n" "$*"; }
ok()    { printf "${c_green}[ ok ]${c_reset} %s\n" "$*"; }
warn()  { printf "${c_yellow}[warn]${c_reset} %s\n" "$*"; }
die()   { printf "${c_red}[erro]${c_reset} %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || die "comando não encontrado: $1"; }

detect_pkg_manager() {
    if   command -v pacman >/dev/null 2>&1; then echo pacman
    elif command -v apt-get >/dev/null 2>&1; then echo apt
    elif command -v dnf    >/dev/null 2>&1; then echo dnf
    else die "distro não suportada (use Arch, Debian/Ubuntu ou Fedora)"
    fi
}

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi

install_deps() {
    local pm
    pm="$(detect_pkg_manager)"
    info "instalando dependências do sistema via $pm..."
    case "$pm" in
        pacman)
            $SUDO pacman -S --noconfirm --needed \
                meson ninja python python-pip python-gobject \
                gtk4 libadwaita glib2 7zip squashfs-tools desktop-file-utils \
                gettext gobject-introspection libgirepository gcc dbus
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
    ok "dependências instaladas"
}

setup_source() {
    if [ -d "$SOURCE_DIR/.git" ]; then
        info "atualizando source em $SOURCE_DIR..."
        git -C "$SOURCE_DIR" pull --ff-only --rebase=false origin "$BRANCH" || warn "git pull falhou; continuando com o source atual"
    else
        info "clonando gearlever ($BRANCH)..."
        mkdir -p "$BASE_DIR"
        git clone --depth 1 --branch "$BRANCH" "$GEARLEVER_REPO" "$SOURCE_DIR"
    fi
    ok "source pronto"
}

setup_venv() {
    need_cmd python3
    if [ ! -x "$VENV_DIR/bin/python" ]; then
        info "criando venv..."
        python3 -m venv --system-site-packages "$VENV_DIR"
    fi
    info "instalando dependências python (pip)..."
    "$VENV_DIR/bin/pip" install --quiet --upgrade pip
    "$VENV_DIR/bin/pip" install --quiet -r "$SOURCE_DIR/requirements.txt"
    ok "venv pronto"
}

build_app() {
    need_cmd meson
    need_cmd ninja
    need_cmd glib-compile-resources
    export PATH="$VENV_DIR/bin:$PATH"
    cd "$SOURCE_DIR"
    if [ -d "$BUILD_DIR" ]; then
        info "reconfigurando build..."
        meson setup --reconfigure "$BUILD_DIR" --prefix "$PREFIX" >/dev/null
    else
        info "configurando build..."
        meson setup "$BUILD_DIR" --prefix "$PREFIX" >/dev/null
    fi
    info "compilando..."
    ninja -C "$BUILD_DIR" >/dev/null
    info "instalando em $PREFIX..."
    meson install -C "$BUILD_DIR" >/dev/null 2>&1 || true
    mkdir -p "$PREFIX/bin" "$PREFIX/share/applications" "$PREFIX/share/metainfo" "$PREFIX/share/glib-2.0/schemas"
    cp "$BUILD_DIR/src/gearlever" "$PREFIX/bin/gearlever"
    chmod +x "$PREFIX/bin/gearlever"
    cp "$BUILD_DIR/data/it.mijorus.gearlever.desktop" "$PREFIX/share/applications/"
    cp "$BUILD_DIR/data/it.mijorus.gearlever.metainfo.xml" "$PREFIX/share/metainfo/"
    cp "$SOURCE_DIR/data/it.mijorus.gearlever.gschema.xml" "$PREFIX/share/glib-2.0/schemas/"
    glib-compile-schemas "$PREFIX/share/glib-2.0/schemas" >/dev/null
    update-desktop-database -q "$PREFIX/share/applications" 2>/dev/null || true
    cp "$SOURCE_DIR/build-aux/get_appimage_offset.sh" "$PREFIX/bin/get_appimage_offset"
    chmod +x "$PREFIX/bin/get_appimage_offset"
    ok "build instalado"
}

verify() {
    if ! "$PREFIX/bin/gearlever" --list-installed >/dev/null 2>&1; then
        die "gearlever não iniciou; verifique as dependências"
    fi
    local ver
    ver="$(grep -A1 "project('gearlever'" "$SOURCE_DIR/meson.build" | grep -oE "version: '[^']+'" | grep -oE "[0-9.]+" || echo "?")"
    ok "gearlever $ver instalado e funcionando"
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
        warn "$PREFIX/bin não está no seu PATH — adicione: export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    printf "\n${c_green}Pronto!${c_reset} Rode: gearlever\n"
}

main "$@"
