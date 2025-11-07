# .dotfiles Qwen Context

## Overview
This is a comprehensive dotfiles repository for a Linux system using the Hyprland window manager. It contains configuration files for various tools and applications, managed using GNU Stow for easy deployment. The system is based on EndeavourOS (Arch-based) with a focus on modern tools and productivity.

## Key Components

### Window Manager & Desktop Environment
- **Hyprland** - A dynamic tiling Wayland compositor
- **Swaync** - Notification center for Wayland compositors
- **Waybar** - Highly customizable Wayland bar
- **Swww** - Wallpapers setter for Wayland compositors
- **Dunst** - Notification daemon

### Terminal & Shell
- **Zsh** with Oh My Zsh framework and Powerlevel10k theme
- **Tmux** for terminal multiplexing
- **Alacritty** and **Kitty** as terminal emulators
- **WezTerm** as an alternative terminal emulator

### Text Editor & Development
- **Neovim** as the primary text editor with a comprehensive plugin setup
- Multiple language support for development (PHP, Python, JavaScript, etc.)

### Application Launchers & Utilities
- **Rofi** (Wayland version) for application launching
- **Yazi** as a modern file manager
- **Fzf** for fuzzy finding with custom key bindings
- **Ghostty** as a GPU-accelerated terminal emulator

## Configuration Structure

The dotfiles are organized in a stow-compatible structure where each directory represents a package of configurations:

- `alacritty/` - Terminal emulator configuration
- `cht.sh/` - CLI cheat sheet configuration
- `docker-config/` - Docker-related scripts and configuration
- `dunst/` - Notification daemon configuration
- `fzf-git/` - Fzf git integration scripts
- `ghostty/` - Ghostty terminal emulator configuration
- `hypr/` - Hyprland compositor configuration
- `kitty/` - Kitty terminal emulator configuration
- `lazygit/` - Lazygit TUI configuration
- `nvim/` - Neovim configuration
- `rofi/` - Rofi application launcher configuration
- `scripts/` - Custom utility scripts
- `swaync/` - Sway notification center configuration
- `tmux/` - Tmux terminal multiplexer configuration
- `traefik/` - Traefik reverse proxy configuration
- `wallpapers/` - Wallpaper collection
- `waybar/` - Waybar status bar configuration
- `wezterm/` - WezTerm terminal configuration
- `zsh/` - Zsh shell configuration with plugins

## Installation & Setup

### Prerequisites
- Arch-based system (specifically EndeavourOS based on the package list)
- GNU Stow for managing the dotfiles
- Yay as AUR helper

### Installation Process
The dotfiles are managed using GNU Stow, where each subdirectory represents a package that can be stowed to deploy configurations:

```bash
# To deploy zsh configurations
stow zsh

# To deploy neovim configurations
stow nvim

# To deploy all configurations
stow */
```

### Package Dependencies
The `pkglist.txt` file contains the complete list of system packages needed for this setup, including:
- Window manager and desktop utilities (Hyprland, Waybar, Swaync)
- Development tools (Neovim, Git, various language runtimes)
- System utilities (htop, btop, eza, bat)
- Applications (Chromium, Firefox, GIMP, OBS Studio)

## Key Features & Customizations

### Shell Environment
- Zsh with Oh My Zsh framework and Powerlevel10k theme
- Custom key bindings and aliases
- Fzf integration for history search and file navigation
- Programming environment support for multiple languages (PHP, Node.js, Go, Python)

### Neovim Configuration
- Modern plugin setup with lazy loading
- Treesitter integration for syntax highlighting
- LSP support for multiple languages
- Git integration with Gitsigns

### Terminal Setup
- Multiple terminal emulator configurations (Alacritty, Kitty, WezTerm, Ghostty)
- Tmux with custom status line and key bindings
- Integration between fzf and other tools

### Development Workflow
- Git aliases and configurations
- Lazygit for Git operations in terminal
- Custom scripts for common tasks (commit message generation, async operations)

## Special Configuration Files

- `.env` - Environment variables including database URLs and API keys
- `keymaps.md` - Documentation of key bindings for various tools
- `aurlist.txt` - List of AUR packages
- `pkglist.txt` - List of system packages
- `.zshrc` - Primary shell configuration with aliases and environment setup

## Development Environment

This setup includes comprehensive development environment configurations for:
- Web development (PHP, Node.js, JavaScript)
- System tools (Python, Shell scripting)
- Containerization (Docker, Docker Compose)
- Version control (Git with custom aliases)

This dotfiles repository represents a modern, productivity-focused Linux desktop environment optimized for development workflows on a Wayland-based system.