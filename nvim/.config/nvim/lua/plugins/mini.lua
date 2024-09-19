return { 
    'echasnovski/mini.nvim',
    version = '*',
    config = function()
        require("mini.pairs").setup()
        require("mini.cursorword").setup()

        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighter = {
                hex_color = hipatterns.gen_highlighter.hex_color(),
            }
        })
    end
}
