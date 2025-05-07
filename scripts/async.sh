#!/bin/bash

set -e

MODE="$1"

PKG_FILE="$HOME/.dotfiles/pkglist.txt"
AUR_FILE="$HOME/.dotfiles/aurlist.txt"

TMP_PKG="/tmp/current_pkg.txt"
TMP_AUR="/tmp/current_aur.txt"

TMP_MISSING_PKG="/tmp/missing_pkg.txt"
TMP_MISSING_AUR="/tmp/missing_aur.txt"

TMP_EXTRA_PKG="/tmp/extra_pkg.txt"
TMP_EXTRA_AUR="/tmp/extra_aur.txt"

TMP_NEW_PKG="/tmp/new_pkg.txt"
TMP_NEW_AUR="/tmp/new_aur.txt"

# Generate current installed package lists
echo "[*] Scanning installed packages..."
pacman -Qqen > "$TMP_PKG"
pacman -Qqem > "$TMP_AUR"

# Ensure list files exist
touch "$PKG_FILE"
touch "$AUR_FILE"

if [[ "$MODE" == "update" ]]; then
  echo "[MODE] Updating machine to match list files"

  # Install missing packages
  comm -23 <(sort "$PKG_FILE") <(sort "$TMP_PKG") > "$TMP_MISSING_PKG"
  comm -23 <(sort "$AUR_FILE") <(sort "$TMP_AUR") > "$TMP_MISSING_AUR"

  if [[ -s "$TMP_MISSING_PKG" ]]; then
    echo "[+] Installing missing official packages:"
    cat "$TMP_MISSING_PKG"
    sudo pacman -S --needed --noconfirm -- < "$TMP_MISSING_PKG"
  else
    echo "[✓] No official packages to install."
  fi

  if [[ -s "$TMP_MISSING_AUR" ]]; then
    echo "[+] Installing missing AUR packages:"
    cat "$TMP_MISSING_AUR"
    yay -S --needed --noconfirm -- < "$TMP_MISSING_AUR"
  else
    echo "[✓] No AUR packages to install."
  fi

  # Remove extra packages
  comm -23 <(sort "$TMP_PKG") <(sort "$PKG_FILE") > "$TMP_EXTRA_PKG"
  comm -23 <(sort "$TMP_AUR") <(sort "$AUR_FILE") > "$TMP_EXTRA_AUR"

  if [[ -s "$TMP_EXTRA_PKG" ]]; then
    echo "[−] Removing extra official packages:"
    cat "$TMP_EXTRA_PKG"
    sudo pacman -Rns --noconfirm $(< "$TMP_EXTRA_PKG")
  else
    echo "[✓] No extra official packages to remove."
  fi

  if [[ -s "$TMP_EXTRA_AUR" ]]; then
    echo "[−] Removing extra AUR packages:"
    cat "$TMP_EXTRA_AUR"
    yay -Rns --noconfirm $(< "$TMP_EXTRA_AUR")
  else
    echo "[✓] No extra AUR packages to remove."
  fi

  echo "[✔] Machine updated to match list files."

elif [[ "$MODE" == "upload" ]]; then
  echo "[MODE] Syncing list files to match current machine"

  # Overwrite list files with current installed packages
  echo "[*] Updating $PKG_FILE with current official packages..."
  cp "$TMP_PKG" "$PKG_FILE"

  echo "[*] Updating $AUR_FILE with current AUR packages..."
  cp "$TMP_AUR" "$AUR_FILE"

  echo "[✔] List files updated to reflect current machine."

else
  echo "Usage: $0 [update|upload]"
  echo "  update  - apply list to machine (install/remove)"
  echo "  upload  - apply machine state to list (overwrite)"
  exit 1
fi

