# .dotfiles

Personal dotfiles for Arch Linux with Hyprland (Wayland). Managed with GNU Stow.

## Structure

| Directory | Tool |
|---|---|
| `fish/` | Shell (fisher, tide prompt, fzf.fish) |
| `hypr/` | Hyprland compositor, window rules, keybinds |
| `waybar/` | Status bar (catppuccin theme, media, weather) |
| `rofi/` | App launcher (catppuccin themes) |
| `swaync/` | Notification center |
| `dunst/` | Notification daemon (fallback) |
| `kitty/` | Terminal emulator (primary) |
| `ghostty/` | Terminal emulator |
| `alacritty/` | Terminal emulator |
| `wezterm/` | Terminal emulator |
| `tmux/` | Terminal multiplexer |
| `zellij/` | Terminal multiplexer |
| `nvim/` | Neovim (LazyVim-based) |
| `mpv/` | Media player (anime upscaling shaders) |
| `yazi/` | Terminal file manager |
| `gitui/` | Git TUI |
| `fzf-git/` | fzf git integration |
| `fcitx5/` | Input method (ibus-compat) |
| `wireplumber/` | Audio session manager |
| `gtk-3.0/`, `gtk-4.0/` | GTK theming |
| `qt6ct/` | Qt6 theming |
| `xdg-desktop-portal/` | Portal config for Hyprland |
| `docker-config/` | Docker Compose dev stack (nginx, php) |
| `traefik/` | Reverse proxy |
| `portainer/` | Docker management UI |
| `systemd/` | User services (fan control) |
| `scripts/` | Utility scripts |
| `fonts/` | Fontconfig |
| `wallpapers/` | Wallpaper collection |
| `mako/` | Notification daemon (legacy) |
| `stremio/` | Stremio mpv config |
| `laravel-config/` | Laravel dev settings |
| `rust-utils/` | Rust CLI tools |

## Dependencies

```bash
# Base
sudo pacman -S stow git base-devel cmake

# AUR helper
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru && makepkg -si

# Hyprland + ecosystem
paru -S hyprland swaybg waybar-hyprland swaync qt6-wayland \
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
  grim slurp wl-clipboard nwg-look nwg-displays

# Terminal
paru -S kitty ghostty alacritty tmux zellij fish fisher

# Shell tools
paru -S fzf fd ripgrep bat eza zoxide btop fastfetch

# Neovim
paru -S neovim python3.10-venv

# Media / files
paru -S mpv mpv-mpris yazi gitui

# Dev
paru -S go php nodejs docker docker-compose traefik

# Input / audio
paru -S fcitx5 fcitx5-gtk fcitx5-qt wireplumber

# Theming
paru -S gtk3 gtk4 qt6ct
```

## Installation

```bash
git clone https://github.com/kienct/.dotfiles ~/.dotfiles
cd ~/.dotfiles

# Stow configs (use only what you need)
stow -t ~ fish hypr waybar rofi swaync          # core desktop
stow -t ~ kitty ghostty tmux nvim yazi gitui    # terminal + dev
stow -t ~ gtk-3.0 gtk-4.0 qt6ct                # theming
stow -t ~ docker-config traefik portainer       # containers
```

For configs that target paths outside `~/.config`, use explicit target:

```bash
stow -t /etc/traefik traefik
```

## Fish Shell

```bash
# Install fisher plugin manager
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher

# Plugins used (auto-installed via fish config)
fisher install patrickf1/fzf.fish
fisher install ilancosman/tide@v6
fisher install jorgebucaran/autopair.fish
fisher install meaningful-ooo/sponge
fisher install franciscolourenco/done
fisher install nickeb96/puffer-fish
```

## Tmux

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Inside tmux: prefix + I to install plugins
```

Plugins: tmux-sensible, tmux-fzf, tmux-fingers, tmux-pain-control, tmux-yank, tmux-prefix-highlight, tmux-nerd-font-window-name, tmux.nvim, tmux-autoreload.

## Neovim

Uses [LazyVim](https://www.lazyvim.org/). Custom plugins and keymaps in `nvim/.config/nvim/lua/`.

First launch runs LazyVim bootstrap automatically.

## Docker

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
# Re-login for group to take effect

# Start dev stack
cd ~/.dotfiles/docker-config/base
docker compose up -d
```

## License

MIT
