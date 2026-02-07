return {
  "echasnovski/mini.files",
  version = false, -- or "*", stability varies for mini plugins sometimes
  config = function()
    require("mini.files").setup({
      -- No need to copy all options, these are just examples
      windows = {
        preview = true,
        width_focus = 50,
        width_nofocus = 15,
      },
      mappings = {
        go_in = '<CR>',
        go_in_plus = 'l',
      },
    })
    -- Example keymap to open mini.files
    vim.keymap.set("n", "<leader>e", function()
      require("mini.files").open(vim.api.nvim_buf_get_name(0))
    end, { desc = "Open mini.files" })
  end,
}
