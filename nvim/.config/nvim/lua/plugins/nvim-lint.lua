return {
  "mfussenegger/nvim-lint",
  opts = {
    -- Event to trigger linters
    events = { "BufWritePost", "BufReadPost", "InsertLeave" },
    linters_by_ft = {
      -- Use the "*" filetype to run linters on all filetypes.
      -- ['*'] = { 'global linter' },
      -- Use the "_" filetype to run linters on filetypes that don't have other linters configured.
      -- ['_'] = { 'fallback linter' },
      -- ["*"] = { "typos" },
      php = { "phpcs", "phpstan" },
    },
    -- LazyVim extension to easily override linter options
    -- or add custom linters.
    ---@type table<string,table>
    linters = {
      -- -- Example of using selene only when a selene.toml file is present
      -- selene = {
      --   -- `condition` is another LazyVim extension that allows you to
      --   -- dynamically enable/disable linters based on the context.
      --   condition = function(ctx)
      --     return vim.fs.find({ "selene.toml" }, { path = ctx.filename, upward = true })[1]
      --   end,
      -- },
      phpcs = {
        args = {
          "--report=json",
          "-q",
          "-s",
          "--stdin-path=%filepath",
          "-",
        },
        condition = function(ctx)
          return vim.fs.find({ "phpcs.xml" }, { path = ctx.filename, upward = true })[1]
        end,
      },
      phpstan = {
        args = {
          "analyse",
          "--error-format=raw",
          "--no-progress",
          "--memory-limit=2G", -- prevent OOM on large files
          "--level=8", -- change to max, 9, or your preferred level
          "--no-interactivity",
          "%filepath",
        },
      },
    },
  },
}
