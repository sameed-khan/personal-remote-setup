return {
  "lewis6991/gitsigns.nvim",
  event = "BufReadPre", -- Load when opening a file in a git repo
  config = function()
    require('gitsigns').setup()
  end
}
