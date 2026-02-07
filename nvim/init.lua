local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Load core options and keymaps before lazy setup
require('core.options')
require('core.keymaps')
require('core.filetypes') -- Register custom filetypes

-- Setup lazy.nvim
require("lazy").setup("plugins", {
  checker = { enabled = true },
})

-- autoread active since Claude Code often edits files underneath
vim.o.autoread = true
