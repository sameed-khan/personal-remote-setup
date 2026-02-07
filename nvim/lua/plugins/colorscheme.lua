return {
  "folke/tokyonight.nvim",
  lazy = false, -- Load this before other plugins that might depend on highlighting
  priority = 1000, -- Ensure it loads early
  config = function()
    require("tokyonight").setup({
      style = "storm", -- "storm", "night", "moon"
      italic_comments = true,
      italic_keywords = true,
      italic_functions = true,
      italic_variables = true, -- As per your g:tokyonight_enable_italic = 1
      -- For g:tokyonight_cursor = 'green', tokyonight.nvim doesn't directly set the
      -- cursor color. This is usually handled by your terminal or by setting
      -- highlight groups like :highlight Cursor guifg=NONE guibg=green
      -- However, some terminal emulators might pick up the theme's general aesthetic.
      -- You can customize specific highlights if needed:
      -- on_highlights = function(hl, c)
      --   hl.Cursor = { bg = "green", fg = c.bg_statusline }
      --   hl.TermCursor = { bg = "green", fg = c.bg_statusline }
      -- end,
    })
    vim.cmd("colorscheme tokyonight")
  end,
}
