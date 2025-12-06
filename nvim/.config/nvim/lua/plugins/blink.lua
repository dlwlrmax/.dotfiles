return {
  {
    "xzbdmw/colorful-menu.nvim",
    config = function()
      require("colorful-menu").setup({
        ls = {
          lua_ls = {
            -- Maybe you want to dim arguments a bit.
            arguments_hl = "@comment",
          },
          gopls = {
            align_type_to_right = true,
            add_colon_before_type = false,
            preserve_type_when_truncate = true,
          },
          ts_ls = {
            extra_info_hl = "@comment",
          },
          vtsls = {
            extra_info_hl = "@comment",
          },
          ["rust-analyzer"] = {
            extra_info_hl = "@comment",
            align_type_to_right = true,
            preserve_type_when_truncate = true,
          },
          clangd = {
            extra_info_hl = "@comment",
            align_type_to_right = true,
            import_dot_hl = "@comment",
            preserve_type_when_truncate = true,
          },
          zls = {
            align_type_to_right = true,
          },
          roslyn = {
            extra_info_hl = "@comment",
          },
          dartls = {
            extra_info_hl = "@comment",
          },
          basedpyright = {
            extra_info_hl = "@comment",
          },
          fallback = true,
          fallback_extra_info_hl = "@comment",
        },
        fallback_highlight = "@variable",
        max_width = 60,
      })
    end,
  },
  {
    "saghen/blink.cmp",
    dependencies = {
      "xieyonn/blink-cmp-dat-word",
    },
    opts = function(_, opts)
      local keymap = {
        preset = "default",
        ["<C-o>"] = { "select_and_accept" },
        ["<A-1>"] = {
          function(cmp)
            cmp.accept({ index = 1 })
          end,
        },
        ["<A-2>"] = {
          function(cmp)
            cmp.accept({ index = 2 })
          end,
        },
        ["<A-3>"] = {
          function(cmp)
            cmp.accept({ index = 3 })
          end,
        },
        ["<A-4>"] = {
          function(cmp)
            cmp.accept({ index = 4 })
          end,
        },
        ["<A-5>"] = {
          function(cmp)
            cmp.accept({ index = 5 })
          end,
        },
        ["<A-6>"] = {
          function(cmp)
            cmp.accept({ index = 6 })
          end,
        },
        ["<A-7>"] = {
          function(cmp)
            cmp.accept({ index = 7 })
          end,
        },
        ["<A-8>"] = {
          function(cmp)
            cmp.accept({ index = 8 })
          end,
        },
        ["<A-9>"] = {
          function(cmp)
            cmp.accept({ index = 9 })
          end,
        },
      }
      local completion = {
        menu = {
          border = "rounded",
          auto_show = true,
          draw = {
            columns = { { "item_idx" }, { "kind_icon", "label", "label_description", gap = 1 }, { "source_name", "kind", gap = 1 } },
            components = {
              label = {
                width = { fill = true, max = 60 },
                text = function(ctx)
                  local highlights_info = require("colorful-menu").blink_highlights(ctx)
                  if highlights_info ~= nil then
                    return highlights_info.label
                  else
                    return ctx.label
                  end
                end,
                highlight = function(ctx)
                  local highlights = {}
                  local highlights_info = require("colorful-menu").blink_highlights(ctx)
                  if highlights_info ~= nil then
                    highlights = highlights_info.highlights
                  end
                  for _, idx in ipairs(ctx.label_matched_indices) do
                    table.insert(highlights, { idx, idx + 1, group = "BlinkCmpLabelMatch" })
                  end
                  return highlights
                end,
              },
              item_idx = {
                text = function(ctx)
                  return tostring(ctx.idx)
                end,
                highlight = "BlinkCmpItemIdx", -- optional, only if you want to change its color
              },
            },
          },
        },
      }
      local cmdline = {
        keymap = {
          ["<C-o>"] = { "select_and_accept" },
        },
      }
      opts.keymap = vim.tbl_deep_extend("force", opts.keymap or {}, keymap)
      opts.completion.menu = vim.tbl_deep_extend("force", opts.completion.menu or {}, completion.menu)
      opts.sources.providers.codeium =
        vim.tbl_deep_extend("force", opts.sources.providers.codeium or {}, { max_items = 3 })
      opts.sources.providers.lsp = vim.tbl_deep_extend('force', opts.sources.providers.lsp or {}, { max_items = 15 })
      opts.sources.providers.buffer =
        vim.tbl_deep_extend("force", opts.sources.providers.buffer or {}, { min_keyword_length = 2 })
      opts.sources = vim.tbl_deep_extend("force", opts.sources or {}, {
        providers = {
          datword = {
            name = "Word",
            module = "blink-cmp-dat-word",
            score_offset = -10,
            opts = {
              paths = { "~/.dotfiles/nvim/.config/nvim/words" },
            },
          },
        },
      })
      opts.sources.default = vim.list_extend(opts.sources.default or {}, { "datword" })
      opts.cmdline = vim.tbl_deep_extend("force", opts.cmdline or {}, cmdline)
    end,
  },
}
