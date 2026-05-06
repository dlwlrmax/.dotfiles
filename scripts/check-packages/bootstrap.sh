#!/bin/bash
# Bootstrap: install go + paru, build check-packages, run it
set -e

DOTFILES="$HOME/.dotfiles"
BIN="$HOME/.local/bin/check-packages"

echo "==> Installing go and paru..."
sudo pacman -S --needed --noconfirm go git base-devel
if ! command -v paru &>/dev/null; then
    echo "==> Installing paru..."
    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin
    cd /tmp/paru-bin && makepkg -si --noconfirm
    rm -rf /tmp/paru-bin
fi

echo "==> Building check-packages..."
cd "$DOTFILES/scripts/check-packages"
go build -o "$BIN" .

echo "==> Done! Run: check-packages"
