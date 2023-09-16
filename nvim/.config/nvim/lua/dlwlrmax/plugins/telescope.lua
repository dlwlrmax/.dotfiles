local telescope_setup, telescope = pcall(require, "telescope")

if not telescope_setup then
  return
end

---@diagnostic disable-next-line: unused-local
local actions_setup, actions = pcall(require, "telescope.actions")
if not actions_setup then
  return
end

telescope.load_extension("fzf")
telescope.load_extension("recent_files")
telescope.setup({
  defaults = {
    file_ignore_patterns = { "node_modules" },
    color_devicons = true,
    mappings = {
      n = { ["q"] = require("telescope.actions").close },
    },
    path_display = { "truncate" },
    preview = {
      filesize_hook = function(filepath, bufnr, opts)
        local max_bytes = 10000
        local cmd = { "head", "-c", max_bytes, filepath }
        require('telescope.previewers.utils').job_maker(cmd, bufnr, opts)
      end
    },
    layout_config = {
      width = 0.8
    }
  },
  picker = {
    find_files = {
      theme = 'dropdown',
    },
  },
  extensions = {
    recent_files = {
      stat_files = true,
      only_cwd = true,
    },
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    },
    media_files = {
      -- filetypes whitelist
      -- defaults to {"png", "jpg", "mp4", "webm", "pdf"}
      filetypes = { "png", "webp", "jpg", "jpeg" },
      -- find command (defaults to `fd`)
      find_cmd = "rg"
    }
  }
})

vim.api.nvim_set_keymap("n", "<leader>fe", [[<cmd>lua require('telescope').extensions.recent_files.pick()<CR>]],
  { noremap = true, silent = true })
