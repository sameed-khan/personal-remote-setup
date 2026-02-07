return {
  "folke/which-key.nvim",
  event = "VeryLazy", -- Load when needed for performance
  opts = {
    -- Use modern preset for better visual appearance
    preset = "modern",

    -- Show popup after a reasonable delay
    delay = function(ctx)
      return ctx.plugin and 0 or 200
    end,

    -- Enable built-in presets for common vim operations
    plugins = {
      presets = {
        operators = false,    -- adds help for operators like d, y, c
        motions = false,      -- adds help for motions
        text_objects = false, -- help for text objects triggered after entering an operator
        windows = true,      -- default bindings on <c-w>
        nav = true,          -- misc bindings to work with windows
        z = true,            -- bindings for folds, spelling and others prefixed with z
        g = true,            -- bindings prefixed with g
      },
    },

    -- Basic window configuration
    win = {
      no_overlap = true,     -- don't allow popup to overlap with cursor
      padding = { 1, 2 },    -- extra window padding [top/bottom, right/left]
      title = true,
      title_pos = "center",
      border = "rounded",    -- border style
    },

    -- Show icons if available
    icons = {
      breadcrumb = "»", -- symbol used in the command line area that shows your active key combo
      separator = "➜", -- symbol used between a key and it's label
      group = "+", -- symbol prepended to a group
    },

    spec = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Buffer Local Keymaps (which-key)" },
      -- Leader-based groups
      { '<leader>b', group = 'Buffer' },
      { '<leader>w', group = 'Window' },
      { '<leader>f', group = 'File/Find' },
      { '<leader>g', group = 'Git' },
      { '<leader>l', group = 'LSP' },

      -- Non-leader groups
      { 'g', group = 'Goto' },
      { ']', group = 'Next' },
      { '[', group = 'Previous' },
      { 'z', group = 'Fold' },
    },
    mode = { 'n', 'v' },
  },
}
