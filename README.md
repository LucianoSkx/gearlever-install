# Gear Lever Install

Installs **Gear Lever** (AppImage manager) by compiling it directly from the official source — no Flatpak, no AUR, no snap.

## Install (one-liner)

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/LucianoSkx/gearlever-install/main/scripts/install.sh)
```

## What it does

- Detects your distro and installs system dependencies (pacman/apt/dnf)
- Clones the official Gear Lever source
- Compiles and installs to `~/.local` (no root)
- Adds the app icon to your applications menu
- Idempotent: run it again to update Gear Lever to the latest version

## Support

| Distro | Package manager |
|--------|-----------------|
| Arch/Manjaro/CachyOS | pacman |
| Debian/Ubuntu/Mint | apt |
| Fedora | dnf |

## Requirements

- `git`, `curl`, `bash`
- `~/.local/bin` in your PATH (add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.bashrc` if needed)

## Uninstall

```sh
rm -rf ~/.local/share/gearlever ~/.local/bin/gearlever ~/.local/bin/get_appimage_offset
rm ~/.local/share/applications/it.mijorus.gearlever.desktop
rm ~/.local/share/metainfo/it.mijorus.gearlever.metainfo.xml
```

## How it works

The official Gear Lever project only ships Flatpak, and the AUR package is often outdated. This script compiles the source (Python + GTK4 + libadwaita) with meson/ninja into `~/.local`, using an isolated venv for the Python dependencies — updates come straight from the official repo.

---

Unofficial project, not affiliated with [mijorus/gearlever](https://github.com/mijorus/gearlever).
