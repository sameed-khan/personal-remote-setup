-- ============================================================================
-- Statusline and Tabline Configuration
-- Uses lualine.nvim for both statusline and tabline (vim tabs as workspaces)
-- ============================================================================

return {
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    event = 'VeryLazy',
    config = function()
      -- Custom component to show tab info
      local function tab_info()
        local current = vim.fn.tabpagenr()
        local total = vim.fn.tabpagenr('$')
        if total > 1 then
          return string.format(' %d/%d', current, total)
        end
        return ''
      end

      require('lualine').setup({
        options = {
          theme = 'tokyonight',
          component_separators = { left = '', right = '' },
          section_separators = { left = '', right = '' },
          globalstatus = true, -- Single statusline for all windows
          disabled_filetypes = {
            statusline = {},
            winbar = {},
          },
        },

        sections = {
          lualine_a = { 'mode' },
          lualine_b = {
            'branch',
            'diff',
            {
              'diagnostics',
              sources = { 'nvim_diagnostic' },
              symbols = { error = ' ', warn = ' ', info = ' ', hint = ' ' },
            },
          },
          lualine_c = {
            {
              'filename',
              path = 1, -- Relative path
              symbols = {
                modified = ' ●',
                readonly = ' ',
                unnamed = '[No Name]',
              },
            },
          },
          lualine_x = { 'encoding', 'fileformat', 'filetype' },
          lualine_y = { 'progress' },
          lualine_z = { 'location', tab_info },
        },

        inactive_sections = {
          lualine_a = {},
          lualine_b = {},
          lualine_c = { 'filename' },
          lualine_x = { 'location' },
          lualine_y = {},
          lualine_z = {},
        },

        -- Tabline shows vim tabs (workspaces)
        tabline = {
          lualine_a = {
            {
              'tabs',
              mode = 2, -- Show tab number and filename
              max_length = vim.o.columns, -- Use full width
              tabs_color = {
                active = 'lualine_a_normal',
                inactive = 'lualine_b_normal',
              },
              fmt = function(name, context)
                -- Show tab number and the active buffer name in that tab
                local buflist = vim.fn.tabpagebuflist(context.tabnr)
                local winnr = vim.fn.tabpagewinnr(context.tabnr)
                local bufnr = buflist[winnr]
                local bufname = vim.fn.bufname(bufnr)
                local filename = vim.fn.fnamemodify(bufname, ':t')
                if filename == '' then
                  filename = '[No Name]'
                end
                -- Add modified indicator
                if vim.fn.getbufvar(bufnr, '&modified') == 1 then
                  filename = filename .. ' ●'
                end
                return string.format('%d: %s', context.tabnr, filename)
              end,
            },
          },
          lualine_b = {},
          lualine_c = {},
          lualine_x = {},
          lualine_y = {},
          lualine_z = {
            {
              function()
                return vim.fn.getcwd():gsub(vim.env.HOME, '~')
              end,
              icon = '',
            },
          },
        },

        extensions = { 'quickfix', 'fugitive' },
      })
    end,
  },
}
