return {
    'mfussenegger/nvim-lint',
    config = function ()
        require('lint').linters_by_fr = {
            lua = { 'luacheck' },
            php = { 'intelephense', 'phpstan' },
        }
    end
}
