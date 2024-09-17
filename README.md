# .dotfiles

## Hyprland Dependencies
`swaybg waypaper-git waybar-hyprland swaync-git qt6-wayland xdg-desktop-portal-hyprland flameshot stow xdg-desktop-portal-gtk grim slurp copyq swaylock-effects`

## Zsh

### Install Oh-my-zsh

`sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"`

### Install Plugin
1. Clone zsh-autosuggestions
`git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions`

2. Clone fast-syntax-highlighting
`git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git \
  ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting`

3. zsh-history-substring-search
`git clone https://github.com/zsh-users/zsh-history-substring-search ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search`

4. MichaelAquilina/zsh-auto-notify
`git clone https://github.com/MichaelAquilina/zsh-auto-notify.git $ZSH_CUSTOM/plugins/auto-notify`

5. zsh-users/zsh-completions.git
`git clone https://github.com/zsh-users/zsh-completions ${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions`

6. Powers10k
`git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k`
7. fzf-zsh-plugin
`git clone --depth 1 https://github.com/unixorn/fzf-zsh-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin`
`git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install`



## Tmux
`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    yay libtmu`

## Neovim
Dependencies

`cmake ripgrep fzf fd python3.10-venv`
## Rate-mirrors
`rate-mirrors --allow-root --protocol https endeavouros | sudo tee /etc/pacman.d/mirrorlist`

## Clipboard
`export DISPLAY="$(grep nameserver /etc/resolv.conf | sed 's/nameserver //'):0"`
