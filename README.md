# Gear Lever Install

Instala o **Gear Lever** (gerenciador de AppImages) compilando direto do source oficial — sem Flatpak, sem AUR, sem snap.

## Instalação (one-liner)

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/LucianoSkx/gearlever-install/main/scripts/install.sh)
```

## O que faz

- Detecta sua distro e instala as dependências de sistema (pacman/apt/dnf)
- Clona o source oficial do Gear Lever
- Compila e instala em `~/.local` (sem root)
- Cria o ícone no menu de aplicativos
- É idempotente: rodar de novo atualiza o Gear Lever para a versão mais recente

## Suporte

| Distro | Gerenciador |
|--------|-------------|
| Arch/Manjaro/CachyOS | pacman |
| Debian/Ubuntu/Mint | apt |
| Fedora | dnf |

## Requisitos

- `git`, `curl`, `bash`
- `~/.local/bin` no seu PATH (adicione `export PATH="$HOME/.local/bin:$PATH"` no seu `~/.bashrc` se necessário)

## Desinstalar

```sh
rm -rf ~/.local/share/gearlever ~/.local/bin/gearlever ~/.local/bin/get_appimage_offset
rm ~/.local/share/applications/it.mijorus.gearlever.desktop
rm ~/.local/share/metainfo/it.mijorus.gearlever.metainfo.xml
```

## Como funciona

O projeto oficial do Gear Lever só distribui Flatpak, e o pacote AUR vive desatualizado. Este script compila o source (Python + GTK4 + libadwaita) com meson/ninja em `~/.local`, usando um venv isolado para as dependências Python — as atualizações saem direto do repo oficial.

---

Projeto não oficial, não afiliado ao [mijorus/gearlever](https://github.com/mijorus/gearlever).