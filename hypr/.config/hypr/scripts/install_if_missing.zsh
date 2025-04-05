#!/usr/bin/env zsh

apps=("bat" "eza" "fzf" "git" "neovim" "ripgrep" "tmux" "zsh" "yazi" "tree" "lazygit" "lazydock" "diff-so-fancy")

for app in $apps; do
  if ! command -v $app &>/dev/null; then
    echo "$app is not installed. Installing with yay..."
    yay -S --noconfirm $app
  else
    echo "$app is already installed ✅"
  fi
done
