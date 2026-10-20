if status is-interactive
    # Vi mode + cursor shapes
    set -g fish_key_bindings fish_user_key_bindings
    set -g fish_cursor_default block
    set -g fish_cursor_insert line blink
    set -g fish_cursor_visual underscore
    set -g fish_cursor_replace_one underscore blink

    # History / autosuggestion
    set -g fish_history_size 100000
    set -g fish_autosuggestion_enabled 1
    set -g fish_greeting ""

    # Env (LANG only when the parent shell did not set one)
    set -gx EDITOR nvim
    test -z "$LANG"; and set -gx LANG en_US.UTF-8
    # OPENCODE_ENABLE_EXA lives in conf.d/oh-my-opencode-slim.fish

    # Secrets: never committed, see .gitignore
    test -f $HOME/.config/fish/secrets.local.fish; and source $HOME/.config/fish/secrets.local.fish

    # FZF - env + bindings
    set -gx FZF_DEFAULT_OPTS '--height 90% --tmux center,90% --layout reverse --border --margin=1 --padding=1'
    set -gx FZF_CTRL_T_OPTS "
    --walker-skip .git,node_modules,target
    --preview 'bat -n --color=always {}'
    --bind 'ctrl-/:change-preview-window(down|hidden|)'"
    set -gx FZF_CTRL_R_OPTS "
    --bind 'ctrl-y:execute-silent(printf %s {3..} | (wl-copy 2>/dev/null; or xclip -selection clipboard 2>/dev/null; or xsel --clipboard --input 2>/dev/null; or cat >/dev/null))+abort'
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

    # Aliases - keep simple, use abbr for git
    abbr -a gs git status
    abbr -a gc git commit
    abbr -a ga git add
    abbr -a cn connect
    alias ls "eza -G --color=auto --icons=auto"
    alias lgit "lazygit"
    alias async "~/.dotfiles/scripts/async.sh"
    alias cmsg "~/.dotfiles/scripts/generate-commit-msg.sh"
    # tracked files only: prevents staging .env / secrets before the AI reads the diff
    alias aicm "git add -u && cmsg"
    alias check-packages "~/.local/bin/check-packages"
    alias docker-setup "~/.dotfiles/docker-config/base/setup-docker.sh"
    alias reload-browser "~/.dotfiles/scripts/reload-browser.sh"
    alias waybar-reload "killall -SIGUSR2 waybar"
    alias wtm "webtorrent --mpv -d 10000 -u 1000 -o ~/Downloads/webtorrent"
    alias wt "webtorrent --mpv -o ~/Downloads/webtorrent"

    # Functions
    function connect --description "sesh connect via fzf"
        set -l selection (sesh list --icons | grep -v -E '(opencode|qwen)' | fzf --ansi --no-sort --height 40% --border --prompt='Select session: ')
        test -n "$selection"; and sesh connect $selection
    end

    function llog --description "tail today's laravel log"
        set -l today (date +%Y-%m-%d)
        for f in "storage/logs/$today.log" "storage/logs/laravel-$today.log" storage/logs/laravel.log
            if test -f $f
                bat --style=full --paging=auto --pager="less +F" $f
                return
            end
        end
        echo "no laravel log found in "(pwd) >&2
        return 1
    end

    function laravel-tail --description "tail -f laravel log"
        set -l today (date +%Y-%m-%d)
        for f in "storage/logs/laravel-$today.log" storage/logs/laravel.log
            if test -f $f
                tail -f $f
                return
            end
        end
        echo "no laravel log found in "(pwd) >&2
        return 1
    end

    # zoxide - lazy init
    if command -v zoxide >/dev/null
        zoxide init fish | source
    end
end
