return {
    'rmagatti/auto-session',
    lazy = false,

    ---enables autocomplete for opts
    ---@module "auto-session"
    ---@type AutoSession.Config
    opts = {
        suppressed_dirs = {'~/', '~/Projects', '~/Downloads', '/'},
        use_git_branch = true,
        close_unsupported_windows = true,
    }
}
