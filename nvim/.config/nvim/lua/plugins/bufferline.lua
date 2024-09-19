return {
    'akinsho/bufferline.nvim',
    version = "*",
    dependencies = 'nvim-tree/nvim-web-devicons',
    config = function()
        require("bufferline").setup({
            options = {
                hover = {
                    enable = true,
                    delay = 200,
                    reveal = { "close" },
                },
                diagnostics = "nvim_lsp",
                diagnostics_indicator = function(count, level)
                    local icon = level:match("error") and " " or " "
                    return "(" .. icon .. count .. ")"
                end,
                offsets = {
                    {
                        filetype = "NvimTree",
                        text = function()
                            return vim.fn.getcwd()
                        end,
                        highlight = "Directory",
                    },
                },
            },
        })
    end
}
