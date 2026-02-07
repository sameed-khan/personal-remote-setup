return {
  -- Enhanced markdown rendering in neovim
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons" -- optional for icons
    },
    opts = {
      -- Render headings with different highlights
      heading = {
        enabled = true,
        sign = true,
        icons = { '󰲡 ', '󰲣 ', '󰲥 ', '󰲧 ', '󰲩 ', '󰲫 ' },
      },
      -- Render code blocks
      code = {
        enabled = true,
        sign = true,
        style = 'full',
        width = 'block',
      },
      -- Render bullet points
      bullet = {
        enabled = true,
        icons = { '●', '○', '◆', '◇' },
      },
      -- Render checkboxes
      checkbox = {
        enabled = true,
        unchecked = { icon = '󰄱 ' },
        checked = { icon = '󰱒 ' },
      },
    },
  },
}
