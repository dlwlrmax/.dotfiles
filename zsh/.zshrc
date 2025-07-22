# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ${ZDOTDIR:-~}/.zshrc

# Set the root name of the plugins files (.txt and .zsh) antidote will use.
zsh_plugins=${ZDOTDIR:-~}/.zsh_plugins

# Ensure the .zsh_plugins.txt file exists so you can add plugins.
[[ -f ${zsh_plugins}.txt ]] || touch ${zsh_plugins}.txt

# Lazy-load antidote from its functions directory.
fpath=(~/.antidote/functions $fpath)
autoload -Uz antidote

# Generate a new static file whenever .zsh_plugins.txt is updated.
if [[ ! ${zsh_plugins}.zsh -nt ${zsh_plugins}.txt ]]; then
  antidote bundle <${zsh_plugins}.txt >|${zsh_plugins}.zsh
fi

# Source your static plugins file.
source ${zsh_plugins}.zsh

ZSH=$(antidote path ohmyzsh/ohmyzsh)
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"
[[ -d $ZSH_CACHE_DIR ]] || mkdir -p $ZSH_CACHE_DIR

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="false"
plugins=(git tmux)

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# CONFIGURE FOR TMUX
# Autostart only if tmux hasn't been started previously
ZSH_TMUX_AUTOSTART_ONCE=true
# Automatically connect to a previous session if it exits
ZSH_TMUX_AUTOCONNECT=true
# Automatically name new sessions based on the basename of the directory
ZSH_TMUX_AUTONAME_SESSION=true


# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='nvim'
# else
#   export EDITOR='nvim'
# fi
export EDITOR="nvim"

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
alias zshconfig="mate ~/.zshrc"
alias szsh="source ~/.zshrc"
alias rr="yazi"
alias connect='sesh connect "$(sesh list | fzf --height 40% --border --prompt="Select session: ")"'
alias waybar-reload="killall -SIGUSR2 waybar"
alias ls="eza -G --color=auto --icons=auto"
alias lgit="lazygit"
alias gopen="~/git.sh"
alias async="~/.dotfiles/scripts/async.sh"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# This for zsh-history-substring-search
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey -v

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh


export FTB_TMUX_POPUP_SIZE='80%x60%'
export FTB_TMUX_POPUP_BORDER=true


# Config jeffreytse/zsh-vi-mode to resolve conflict issue with zsh-history-substring-search
function zvm_after_init() {
    # Ensure fzf key-bindings are sourced *after* zsh-vi-mode has initialized its own bindings.
    # This ensures fzf's bindings take precedence where desired.

    # Source fzf key-bindings
    if [ -f "/usr/share/fzf/key-bindings.zsh" ]; then
        # For system-wide fzf installation (e.g., via apt, pacman, brew)
        source "/usr/share/fzf/key-bindings.zsh"
    elif [ -f "$HOME/.fzf.zsh" ]; then
        # For fzf installed via its own install script
        source "$HOME/.fzf.zsh"
    fi

    # Source fzf-git script if it exists
    # This should also come after fzf key-bindings if fzf-git provides its own keybinds
    if [ -f "$HOME/.dotfiles/fzf-git/script.sh" ]; then
        source "$HOME/.dotfiles/fzf-git/script.sh"
    fi

    # Enable fzf-tab. This usually integrates with fzf's existing bindings.
    # It's good to call it last in the fzf-related section.
    if command -v enable-fzf-tab &> /dev/null; then
        enable-fzf-tab
    fi
}

ZVM_VI_INSERT_ESCAPE_BINDKEY=jj

zstyle ':tmux:*' auto-title on
zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
# Git branches
zstyle ':completion:*:git-checkout:*' sort false

zstyle ':completion:*:git-checkout:*' preview \
  'branch={${(Q)words[-1]}}; git for-each-ref --format="%(committerdate:relative)" "refs/heads/$branch" 2>/dev/null || echo "No info"' ftb-tmux-popup

# Git log preview for fzf-tab
zstyle ':fzf-tab:complete:git-log:*' fzf-preview \
  '[[ -n "$1" ]] && git show --color=always "$1" || echo "No commit selected"'
## fzf config
# Open in tmux popup if on tmux, otherwise use --height mode
export FZF_DEFAULT_OPTS='--height 90% --tmux center,90% --layout reverse --border --margin=1 --padding=1'

# Preview file content using bat (https://github.com/sharkdp/bat)
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# CTRL-Y to copy the command into clipboard using pbcopy
export FZF_CTRL_R_OPTS="
  --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"

# Print tree structure in the preview window
export FZF_ALT_C_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'tree -C {}'"

source <(fzf --zsh)

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

export PATH="$HOME/.config/composer/vendor/bin:$PATH"

# Golang
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$PATH


# PHPBREW
export PHPBREW_SET_PROMPT=1
export PHPBREW_RC_ENABLE=1
[[ -e ~/.phpbrew/bashrc ]] && source ~/.phpbrew/bashrc


# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


eval "$(zoxide init zsh)"
