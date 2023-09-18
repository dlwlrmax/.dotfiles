-- config filetypes
local api = vim.api
local opt = vim.opt
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "php" },
  callback = function()
    opt.shiftwidth = 4
    opt.tabstop = 4
  end
})
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "html", "txt", "css", "scss" },
  callback = function()
    opt.shiftwidth = 2
    opt.tabstop = 2
  end
})

local bufferlineSetup, _ = pcall(require, 'bufferline')

if not bufferlineSetup then
  return
end


api.nvim_create_autocmd('BufWinEnter', {
  pattern = '*',
  callback = function()
    if vim.bo.filetype == 'NvimTree' then
      require'bufferline.api'.set_offset(31, 'FileTree')
    end
  end
})

api.nvim_create_autocmd('BufWinLeave', {
  pattern = '*',
  callback = function()
    if vim.fn.expand('<afile>'):match('NvimTree') then
      require'bufferline.api'.set_offset(0)
    end
  end
})

local barbecueSetup, _ = pcall(require, 'barbecue')

if not barbecueSetup then
  return
end

vim.api.nvim_create_autocmd({
  "WinScrolled", -- or WinResized on NVIM-v0.9 and higher
  "BufWinEnter",
  "CursorHold",
  "InsertLeave",

  -- include these if you have set `show_modified` to `true`
  "BufWritePost",
  "TextChanged",
  "TextChangedI",
}, {
  group = vim.api.nvim_create_augroup("barbecue.updater", {}),
  callback = function()
    require("barbecue.ui").update()
  end,
})
