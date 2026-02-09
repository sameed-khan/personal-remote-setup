-- telescope.lua - Telescope configuration
return {
  -- Main telescope plugin
  {
    'nvim-telescope/telescope.nvim',
    branch = 'master',
    dependencies = {
      'nvim-lua/plenary.nvim',
      -- Better sorting performance with fzf
      {
        'nvim-telescope/telescope-fzf-native.nvim',
        build = 'make',
        cond = function()
          return vim.fn.executable('make') == 1
        end,
      },
      'nvim-telescope/telescope-live-grep-args.nvim',
    },
    cmd = 'Telescope',
    keys = function()
      local builtin = require('telescope.builtin')
      local telescope = require('telescope')

      -- Buffer picker with delete functionality
      local function buffer_picker()
        builtin.buffers({
          sort_mru = true,
          sort_lastused = true,
          ignore_current_buffer = true,
          initial_mode = 'normal',
          attach_mappings = function(prompt_bufnr, map)
            local actions = require('telescope.actions')
            local action_state = require('telescope.actions.state')

            -- Delete buffer(s) with 'd' in normal mode or <C-d> in insert mode
            local delete_buf = function()
              local current_picker = action_state.get_current_picker(prompt_bufnr)
              local multi_selections = current_picker:get_multi_selection()

              if #multi_selections > 0 then
                -- Delete multiple selected buffers
                for _, selection in ipairs(multi_selections) do
                  vim.api.nvim_buf_delete(selection.bufnr, { force = true })
                end
              else
                -- Delete single buffer under cursor
                local selection = action_state.get_selected_entry()
                if selection then
                  vim.api.nvim_buf_delete(selection.bufnr, { force = true })
                end
              end

              -- Refresh the picker
              actions.close(prompt_bufnr)
              vim.schedule(buffer_picker)
            end

            map('n', 'd', delete_buf)
            map('n', 'dd', delete_buf)
            map('i', '<C-d>', delete_buf)

            return true
          end,
        })
      end

      return {
        -- Buffer navigation (not under <leader>f prefix)
        { '<leader><leader>', buffer_picker, desc = 'Switch Buffer' },

        -- File finding operations
        { '<leader>ff', function() builtin.find_files({ hidden = false }) end, desc = 'Find Files' },
        { '<leader>fF', function() builtin.find_files({ hidden = true, no_ignore = true }) end, desc = 'Find Files (All)' },
        { '<leader>fs', function() telescope.extensions.live_grep_args.live_grep_args() end, desc = 'Live Grep' },
        { '<leader>fG', function() telescope.extensions.live_grep_args.live_grep_args({ hidden = true, no_ignore = true }) end, desc = 'Live Grep (All)' },

        -- Recent files
        { '<leader>fr', builtin.oldfiles, desc = 'Recent Files' },
        { '<leader>fR', builtin.resume, desc = 'Resume Last Search' },

        -- Search in current buffer
        { '<leader>f/', builtin.current_buffer_fuzzy_find, desc = 'Fuzzy Search in Buffer' },

        -- Git operations (if in a git repo)
        { '<leader>fgc', builtin.git_commits, desc = 'Git Commits' },
        { '<leader>fgb', builtin.git_branches, desc = 'Git Branches' },
        { '<leader>fgs', builtin.git_status, desc = 'Git Status' },

        -- Help and documentation
        { '<leader>fh', builtin.help_tags, desc = 'Help Tags' },
        { '<leader>fm', builtin.man_pages, desc = 'Man Pages' },
        { '<leader>fk', builtin.keymaps, desc = 'Keymaps' },
        { '<leader>fc', builtin.commands, desc = 'Commands' },

        -- LSP operations (when LSP is attached)
        { '<leader>fls', builtin.lsp_document_symbols, desc = 'Document Symbols' },
        { '<leader>flS', builtin.lsp_workspace_symbols, desc = 'Workspace Symbols' },
        { '<leader>fld', builtin.diagnostics, desc = 'Diagnostics' },
      }
    end,
    config = function()
      local telescope = require('telescope')
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      telescope.setup({
        defaults = {
          -- Better layout
          layout_config = {
            horizontal = {
              preview_width = 0.55,
              results_width = 0.8,
            },
            vertical = {
              mirror = false,
            },
            width = 0.85,
            height = 0.85,
            preview_cutoff = 120,
          },

          -- Better performance
          file_ignore_patterns = {
            'node_modules',
            '.git/',
            'dist/',
            'build/',
            '%.pyc',
            '__pycache__',
            '%.o',
            '%.a',
            '%.out',
            '%.pdf',
            '%.mkv',
            '%.mp4',
            '%.zip',
          },

          -- Visual improvements
          prompt_prefix = '   ',
          selection_caret = '  ',
          entry_prefix = '  ',
          initial_mode = 'insert',
          selection_strategy = 'reset',
          sorting_strategy = 'ascending',
          layout_strategy = 'horizontal',

          -- Mappings
          mappings = {
            i = {
              -- Navigation
              ['<C-j>'] = actions.move_selection_next,
              ['<C-k>'] = actions.move_selection_previous,
              ['<C-n>'] = actions.cycle_history_next,
              ['<C-p>'] = actions.cycle_history_prev,

              -- Actions
              ['<C-c>'] = actions.close,
              ['<C-x>'] = actions.select_horizontal,
              ['<C-v>'] = actions.select_vertical,
              ['<C-t>'] = actions.select_tab,

              -- Preview scrolling
              ['<C-u>'] = actions.preview_scrolling_up,
              ['<C-d>'] = actions.preview_scrolling_down,

              -- Toggle selection and move
              ['<Tab>'] = actions.toggle_selection + actions.move_selection_worse,
              ['<S-Tab>'] = actions.toggle_selection + actions.move_selection_better,

              -- Send to quickfix
              ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
              ['<M-q>'] = actions.send_to_qflist + actions.open_qflist,

              -- Toggle hidden files (custom action)
              ['<C-h>'] = function(prompt_bufnr)
                local current_picker = action_state.get_current_picker(prompt_bufnr)
                local finder = current_picker.finder

                -- Toggle hidden state
                local hidden = not (finder.hidden or false)
                finder.hidden = hidden

                -- Notify user
                vim.notify('Hidden files: ' .. (hidden and 'shown' or 'hidden'), vim.log.levels.INFO)

                -- Refresh picker with new settings
                actions.close(prompt_bufnr)
                vim.schedule(function()
                  if current_picker.prompt_title:match('Find Files') then
                    require('telescope.builtin').find_files({ hidden = hidden })
                  elseif current_picker.prompt_title:match('Live Grep') then
                    require('telescope').extensions.live_grep_args.live_grep_args({
                      additional_args = hidden and {'--hidden'} or {}
                    })
                  end
                end)
              end,
            },
            n = {
              -- Normal mode mappings
              ['<esc>'] = actions.close,
							['q'] = actions.close,
              ['<CR>'] = actions.select_default,
              ['x'] = actions.select_horizontal,
              ['v'] = actions.select_vertical,
              ['t'] = actions.select_tab,

              ['<Tab>'] = actions.toggle_selection + actions.move_selection_worse,
              ['<S-Tab>'] = actions.toggle_selection + actions.move_selection_better,
              ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
              ['<M-q>'] = actions.send_to_qflist + actions.open_qflist,

              ['j'] = actions.move_selection_next,
              ['k'] = actions.move_selection_previous,
              ['H'] = actions.move_to_top,
              ['M'] = actions.move_to_middle,
              ['L'] = actions.move_to_bottom,

              ['gg'] = actions.move_to_top,
              ['G'] = actions.move_to_bottom,

              ['?'] = actions.which_key,
            },
          },

          -- Use ripgrep for better performance
          vimgrep_arguments = {
            'rg',
            '--color=never',
            '--no-heading',
            '--with-filename',
            '--line-number',
            '--column',
            '--smart-case',
            '--trim', -- Remove indentation
          },
        },

        pickers = {
          find_files = {
            -- Custom find command for better performance
            find_command = { 'fd', '--type', 'f', '--strip-cwd-prefix' },
            hidden = false, -- Start with hidden files off
          },
          buffers = {
            show_all_buffers = true,
            sort_mru = true,
            mappings = {
              i = {
                ['<c-d>'] = 'delete_buffer',
              },
              n = {
                ['d'] = 'delete_buffer',
              },
            },
          },
          live_grep = {
            additional_args = function()
              return { '--hidden' }
            end,
          },
        },

        extensions = {
          fzf = {
            fuzzy = true,
            override_generic_sorter = true,
            override_file_sorter = true,
            case_mode = 'smart_case',
          },
          live_grep_args = {
            auto_quoting = true,
            mappings = {
              i = {
                ['<C-k>'] = require('telescope-live-grep-args.actions').quote_prompt(),
                ['<C-i>'] = require('telescope-live-grep-args.actions').quote_prompt({ postfix = ' --iglob ' }),
              },
            },
          },
        },
      })

      -- Load extensions
      telescope.load_extension('fzf')
      telescope.load_extension('live_grep_args')

      -- Set up highlights for better visibility
      vim.api.nvim_set_hl(0, 'TelescopeMatching', { fg = '#ff9e64' })
      vim.api.nvim_set_hl(0, 'TelescopeSelection', { bg = '#3d59a1', fg = '#c0caf5', bold = true })
      vim.api.nvim_set_hl(0, 'TelescopePreviewBorder', { fg = '#7aa2f7' })
      vim.api.nvim_set_hl(0, 'TelescopePromptBorder', { fg = '#7aa2f7' })
      vim.api.nvim_set_hl(0, 'TelescopeResultsBorder', { fg = '#7aa2f7' })
    end,
  },
}
