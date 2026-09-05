if status is-interactive
    # Vi mode + cursor shapes
    set -g fish_key_bindings fish_vi_key_bindings
    set -g fish_cursor_default block
    set -g fish_cursor_insert line blink
    set -g fish_cursor_visual underscore
    set -g fish_cursor_replace_one underscore blink

    # History / autosuggestion / fish 4 features
    set -g fish_history_size 100000
    set -g fish_autosuggestion_enabled 1
    set -g fish_features qmark-noglob,regex-easyesc,ampersand-nobg-in-token
    set -g fish_greeting ""

    # Env
    set -gx EDITOR nvim
    set -gx LANG en_US.UTF-8
    set -gx OPENCODE_ENABLE_EXA 1

    # FZF - env + bindings
    set -gx FZF_DEFAULT_OPTS '--height 90% --tmux center,90% --layout reverse --border --margin=1 --padding=1'
    set -gx FZF_CTRL_T_OPTS "
    --walker-skip .git,node_modules,target
    --preview 'bat -n --color=always {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    set -gx FZF_CTRL_R_OPTS "
    --bind 'ctrl-y:execute-silent(echo -n {2..} | xclip -selection clipboard)+abort'
    --color header:italic
    --header 'Press CTRL-Y to copy command into clipboard'"
    set -gx FZF_ALT_C_OPTS "
    --walker-skip .git,node_modules,target
    --preview 'tree -C {}'"

    if command -v fzf >/dev/null
        fzf --fish | source
    end

    # Paths - deduped via fish_add_path (in order of priority)
    fish_add_path --move --prepend $HOME/.local/bin
    fish_add_path --move --prepend $HOME/.cargo/bin
    fish_add_path --move --prepend $HOME/go/bin
    fish_add_path $HOME/.config/composer/vendor/bin
    fish_add_path $HOME/.opencode/bin
    fish_add_path $HOME/.local/share/pnpm/bin

    # Tool-specific env (keep lightweight)
    set -gx GOPATH $HOME/go
    set -gx PNPM_HOME "$HOME/.local/share/pnpm"
    set -gx BUN_INSTALL "$HOME/.bun"
    fish_add_path $BUN_INSTALL/bin
    set -gx TUNNELTO_INSTALL "$HOME/.tunnelto"
    fish_add_path $TUNNELTO_INSTALL/bin
    set -gx PHPBREW_SET_PROMPT 1
    set -gx PHPBREW_RC_ENABLE 1
    set -gx COREPACK_ENABLE_AUTO_PIN 0

    # MySQL MCP
    set -gx MYSQL_HOST "192.168.3.213"
    set -gx MYSQL_PORT "3306"
    set -gx MYSQL_USER "dev"
    set -gx MYSQL_PASSWORD "LangTech@123"

    # Aliases - keep simple, use abbr for git
    abbr -a gs git status
    abbr -a gc git commit
    abbr -a ga git add
    alias ls "eza -G --color=auto --icons=auto"
    alias lgit "lazygit"
    alias gopen "~/git.sh"
    alias async "~/.dotfiles/scripts/async.sh"
    alias cmsg "~/.dotfiles/scripts/generate-commit-msg.sh"
    alias aicm "git add . && cmsg"
    alias check-packages "~/.local/bin/check-packages"
    alias docker-setup "~/.dotfiles/docker-config/base/setup-docker.sh"
    alias reload-browser "~/.dotfiles/scripts/reload-browser.sh"
    alias waybar-reload "killall -SIGUSR2 waybar"
    alias wtm "webtorrent --mpv -d 10000 -u 1000 -o ~/Downloads/webtorrent"
    alias wt "webtorrent --mpv -o ~/Downloads/webtorrent"

    # Functions - dedup connect/cn
    function connect --description "sesh connect via fzf"
        sesh connect (sesh list | grep -v -E '(opencode|qwen)' | fzf --height 40% --border --prompt='Select session: ')
    end
    function cn --description "alias for connect"
        connect
    end

    function llog --description "tail laravel log for today"
        set -l today (date +%Y-%m-%d)
        if test -f "storage/logs/$today.log"
            bat --style=full --paging=auto --pager="less +F" "storage/logs/$today.log"
        else if test -f "storage/logs/laravel-$today.log"
            bat --style=full --paging=auto --pager="less +F" "storage/logs/laravel-$today.log"
        else
            bat --style=full --paging=auto --pager="less +F" "storage/logs/laravel.log"
        end
    end

    function laravel-tail --description "tail -f laravel log"
        set -l today (date +%Y-%m-%d)
        if test -f "storage/logs/laravel-$today.log"
            tail -f "storage/logs/laravel-$today.log"
        else
            tail -f "storage/logs/laravel.log"
        end
    end

    # zoxide - lazy init
    if command -v zoxide >/dev/null
        zoxide init fish | source
    end

    # macchina - run once per session, not every shell
    if type -q macchina; and not set -q _macchina_ran
        macchina
        set -g _macchina_ran 1
    end

    # sesh auto-connect - only if truly standalone (no tmux, no existing sesh session)
    if test -z "$TMUX"; and test -z "$SESH_SESSION"; and status is-interactive
        # uncomment to enable auto-connect
        # sesh connect ~/.dotfiles
    end
end
