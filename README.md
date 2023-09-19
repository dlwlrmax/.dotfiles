# .dotfiles

## Hyprland Dependencies
    swaybg waypaper-git waybar-hyprland swaync-git qt6-wayland xdg-desktop-portal-hyprland flameshot stow xdg-desktop-portal-gtk grim slurp copyq swaylock-effects

## Antidote
Install with git

    git clone --depth=1 https://github.com/mattmc3/antidote.git ${ZDOTDIR:-~}/.antidote
Or AUR

    yay -S zsh-antidote

Run antidote

    # generate ~/.zsh_plugins.zsh
    antidote bundle <~/.zsh_plugins.txt >~/.zsh_plugins.zsh

## Tmux
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    yay libtmu

## Neovim
Dependencies

    cmake ripgrep fzf fd
## Rate-mirrors
    rate-mirrors --allow-root --protocol https endeavouros | sudo tee /etc/pacman.d/mirrorlis
