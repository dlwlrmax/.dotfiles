if status is-interactive
    # Enable vi mode
    fish_vi_key_bindings

    # Generate WM-specific ghostty config (e.g., window-decoration for Hyprland)
    generate_ghostty_wm_config

    # Environment variables
    set -x EDITOR nvim
    set -x LANG en_US.UTF-8

    # FZF configuration
    set -x FZF_DEFAULT_OPTS '--height 90% --tmux center,90% --layout reverse --border --margin=1 --padding=1'
    set -x FZF_CTRL_T_OPTS "
    --walker-skip .git,node_modules,target
    --preview 'bat -n --color=always {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    set -x FZF_CTRL_R_OPTS "
    --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"
    set -x FZF_ALT_C_OPTS "
    --walker-skip .git,node_modules,target
    --preview 'tree -C {}'"

    # PNPM
    set -x PNPM_HOME "$HOME/.local/share/pnpm"
    if not contains $PNPM_HOME $PATH
        set -x PATH $PNPM_HOME $PATH
    end

    # PHP Composer
    set -x PATH "$HOME/.config/composer/vendor/bin" $PATH

    # Golang
    set -x GOPATH $HOME/go
    set -x PATH $GOPATH/bin $PATH

    # PHPBREW
    set -x PHPBREW_SET_PROMPT 1
    set -x PHPBREW_RC_ENABLE 1

    # Corepack
    set -x COREPACK_ENABLE_AUTO_PIN 0

    # Additional tools
    set -x TUNNELTO_INSTALL "/home/kienct/.tunnelto"
    set -x PATH $TUNNELTO_INSTALL/bin $PATH
    set -x PATH /home/kienct/.opencode/bin $PATH
    set -x PATH /home/kienct/.local/bin $PATH
    set -x PATH $HOME/.cargo/bin $PATH

    # Simple aliases
    alias rr="yazi"
    alias waybar-reload="killall -SIGUSR2 waybar"
    alias ls="eza -G --color=auto --icons=auto"
    alias lgit="lazygit"
    alias gopen="~/git.sh"
    alias async="~/.dotfiles/scripts/async.sh"
    alias cmsg="~/.dotfiles/scripts/generate-commit-msg.sh"
    alias aicm="git add . && cmsg"
    alias docker-setup="~/.dotfiles/docker-config/base/setup-docker.sh"
    alias reload-browser="~/.dotfiles/scripts/reload-browser.sh"

    # Complex aliases as functions
    function connect
        sesh connect (sesh list | grep -v -E '(opencode|qwen)' | fzf --height 40% --border --prompt='Select session: ')
    end

    function cn
        sesh connect (sesh list | grep -v -E '(opencode|qwen)' | fzf --height 40% --border --prompt='Select session: ')
    end

    function llog
        set today (date +%Y-%m-%d)
        if test -f "storage/logs/$today.log"
            bat --style=full --paging=auto --pager="less +F" "storage/logs/$today.log"
        else if test -f "storage/logs/laravel-$today.log"
            bat --style=full --paging=auto --pager="less +F" "storage/logs/laravel-$today.log"
        else
            bat --style=full --paging=auto --pager="less +F" "storage/logs/laravel.log"
        end
    end

    function laravel-tail
        set today (date +%Y-%m-%d)
        if test -f "storage/logs/laravel-$today.log"
            tail -f "storage/logs/laravel-$today.log"
        else
            tail -f "storage/logs/laravel.log"
        end
    end

    # Initialize zoxide
    if command -v zoxide >/dev/null
        zoxide init fish | source
    end

    if type -q macchina
        macchina
    end

    set fish_greeting ""
end
