return {
  "m-demare/hlargs.nvim",
  event = "LspAttach",
  init = function()
    -- autocmds.lua loads on VeryLazy, possibly after the first LspAttach;
    -- register here (startup) so hlargs is disabled on semantic-token servers.
    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("LspAttach_hlargs", { clear = true }),
      callback = function(args)
        local client = args.data and args.data.client_id and vim.lsp.get_client_by_id(args.data.client_id)
        if not client then
          return
        end
        if client:supports_method("textDocument/semanticTokens/full") then
          require("hlargs").disable_buf(args.buf)
        end
      end,
    })
  end,
  config = function()
    local hlargs = require("hlargs")
    hlargs.setup({
      color = "#FAAB78",
      highlight = {},
      excluded_filetypes = {},
      paint_arg_declarations = true,
      paint_arg_usages = true,
      paint_catch_blocks = {
        declarations = false,
        usages = false,
      },
      extras = {
        named_parameters = false,
      },
      hl_priority = 10000,
      excluded_argnames = {
        declarations = {},
        usages = {
          python = { "self", "cls" },
          lua = { "self" },
        },
      },
      performance = {
        parse_delay = 100,
        slow_parse_delay = 200,
        max_iterations = 400,
        max_concurrent_partial_parses = 30,
        debounce = {
          partial_parse = 20,
          partial_insert_mode = 100,
          total_parse = 700,
          slow_parse = 5000,
        },
      },
    })

    hlargs.enable()
  end,
}
