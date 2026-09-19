# auto --continue khi mở TUI trần (không subcommand) — `opencode` mở lại last session
# subcommand giữ nguyên. Tắt 1 lần: `command opencode`
function opencode --wraps=opencode --description "auto-continue last session on bare launch"
    if test (count $argv) -eq 0
        command opencode --continue
        return
    end
    switch "$argv[1]"
        case run session service serve auth mcp plugin models stats upgrade update uninstall acp api debug reload pair mini help --help -h --version -v --wizard --completions -c --continue -s --session --fork
            command opencode $argv
        case '*'
            command opencode --continue $argv
    end
end
