-- ============================================================================
-- Consolidated Keymap Configuration
-- All keymaps from across plugins consolidated into one place
-- ============================================================================

local map = vim.keymap.set

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Custom function to select last pasted/changed text using '[ and '] marks
local function select_last_pasted()
  -- Get the marks for the last changed text (which includes pasted text)
  local start_mark = vim.api.nvim_buf_get_mark(0, '[')
  local end_mark = vim.api.nvim_buf_get_mark(0, ']')
  
  -- Check if marks are valid
  if start_mark[1] == 0 or end_mark[1] == 0 then
    vim.notify("No previous paste/change to select", vim.log.levels.WARN)
    return
  end
  
  -- Move to start position and enter visual mode
  vim.api.nvim_win_set_cursor(0, start_mark)
  vim.cmd('normal! v')
  
  -- Move to end position to complete selection
  vim.api.nvim_win_set_cursor(0, end_mark)
end

-- Function to select original last visual selection (built-in gv behavior)
local function select_last_visual()
  vim.cmd('normal! gv')
end

-- ============================================================================
-- CORE MOVEMENT & EDITING
-- ============================================================================

-- Insert mode escape
map('i', 'jk', '<Esc>', { desc = 'Escape insert mode' })

-- Clear search highlight
map('n', '<Leader>h', ':nohlsearch<CR>', { desc = 'Clear search highlight' })

-- Visual block movement (move selected lines up/down)
map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Better indentation (keeps selection)
map('v', '<', '<gv', { desc = 'Indent left and reselect' })
map('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Enhanced selection keymaps
map('n', 'gv', select_last_pasted, { desc = 'Select last pasted/changed text' })
map('n', 'gV', select_last_visual, { desc = 'Select last visual selection (original gv)' })

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

-- Window splits
map('n', '<Leader>wh', ':vsplit<CR>', { desc = 'Split window vertically (new window left)' })
map('n', '<Leader>wl', ':belowright vsplit<CR>', { desc = 'Split window vertically (new window right)' })
map('n', '<Leader>wj', ':belowright split<CR>', { desc = 'Split window horizontally (new window below)' })
map('n', '<Leader>wk', ':split<CR>', { desc = 'Split window horizontally (new window above)' })

-- Window management
map('n', '<Leader>wq', ':close<CR>', { desc = 'Close current window' })
map('n', '<Leader>wo', ':only<CR>', { desc = 'Close all other windows' })

-- Window navigation
map('n', '<C-h>', '<C-w>h', { desc = 'Navigate to left window' })
map('n', '<C-j>', '<C-w>j', { desc = 'Navigate to below window' })
map('n', '<C-k>', '<C-w>k', { desc = 'Navigate to above window' })
map('n', '<C-l>', '<C-w>l', { desc = 'Navigate to right window' })

-- Window resizing
map('n', '<C-Up>', ':resize -2<CR>', { desc = 'Decrease window height' })
map('n', '<C-Down>', ':resize +2<CR>', { desc = 'Increase window height' })
map('n', '<C-Left>', ':vertical resize -2<CR>', { desc = 'Decrease window width' })
map('n', '<C-Right>', ':vertical resize +2<CR>', { desc = 'Increase window width' })

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================

-- Buffer navigation (telescope buffer picker is defined in plugins/telescope.lua)
map('n', '<Leader>ba', '<C-6>', { desc = 'Toggle to alternate buffer' })
map('n', ']b', ':bnext<CR>', { desc = 'Next buffer' })
map('n', '[b', ':bprevious<CR>', { desc = 'Previous buffer' })

-- Buffer management (force delete to avoid "unsaved changes" prompts)
map('n', '<Leader>bd', ':bdelete!<CR>', { desc = 'Delete buffer (force)' })
map('n', '<Leader>bo', ':%bdelete!|edit #|normal `"<CR>', { desc = 'Close all other buffers (force)' })

-- ============================================================================
-- TAB (WORKSPACE) MANAGEMENT
-- ============================================================================

-- Tab navigation
map('n', '<Leader><Tab>n', ':tabnew<CR>', { desc = 'New tab' })
map('n', '<Leader><Tab>c', ':tabclose<CR>', { desc = 'Close tab' })
map('n', '<Leader><Tab>o', ':tabonly<CR>', { desc = 'Close other tabs' })
map('n', '<Leader><Tab>]', ':tabnext<CR>', { desc = 'Next tab' })
map('n', '<Leader><Tab>[', ':tabprevious<CR>', { desc = 'Previous tab' })
map('n', '<Leader><Tab>l', ':tablast<CR>', { desc = 'Last tab' })
map('n', '<Leader><Tab>f', ':tabfirst<CR>', { desc = 'First tab' })

-- Quick tab switching with <leader>1-9
for i = 1, 9 do
  map('n', '<Leader>' .. i, i .. 'gt', { desc = 'Go to tab ' .. i })
end

-- ============================================================================
-- FILE MANAGEMENT
-- ============================================================================

-- File explorer (mini.files)
map('n', '<leader>e', function()
  require('mini.files').open(vim.api.nvim_buf_get_name(0))
end, { desc = 'Open file explorer' })

-- ============================================================================
-- LSP KEYMAPS (Applied when LSP attaches to buffer)
-- ============================================================================

-- Set up LSP keymaps when LSP attaches
vim.api.nvim_create_autocmd('LspAttach', {
  desc = 'LSP actions',
  callback = function(event)
    local opts = { buffer = event.buf }
    
    -- Override default K mapping to disable it (we use gh instead)
    map('n', 'K', '<nop>', vim.tbl_extend('force', opts, { desc = 'Disabled (use gh for hover)' }))
    
    -- LSP navigation and information
    map('n', 'gh', vim.lsp.buf.hover, vim.tbl_extend('force', opts, { desc = 'LSP: Hover/Peek Documentation' }))
    map('n', 'gd', vim.lsp.buf.definition, vim.tbl_extend('force', opts, { desc = 'LSP: Go to Definition' }))
    map('n', 'gD', vim.lsp.buf.declaration, vim.tbl_extend('force', opts, { desc = 'LSP: Go to Declaration' }))
    map('n', 'gi', vim.lsp.buf.implementation, vim.tbl_extend('force', opts, { desc = 'LSP: Go to Implementation' }))
    map('n', 'go', vim.lsp.buf.type_definition, vim.tbl_extend('force', opts, { desc = 'LSP: Go to Type Definition' }))
    map('n', 'gr', vim.lsp.buf.references, vim.tbl_extend('force', opts, { desc = 'LSP: Show References' }))
    map('n', 'gs', vim.lsp.buf.signature_help, vim.tbl_extend('force', opts, { desc = 'LSP: Signature Help' }))
    
    -- Diagnostic navigation
    map('n', ']d', vim.diagnostic.goto_next, vim.tbl_extend('force', opts, { desc = 'LSP: Next Diagnostic' }))
    map('n', '[d', vim.diagnostic.goto_prev, vim.tbl_extend('force', opts, { desc = 'LSP: Previous Diagnostic' }))
    
    -- LSP actions
    map('n', '<F2>', vim.lsp.buf.rename, vim.tbl_extend('force', opts, { desc = 'LSP: Rename Symbol' }))
    map({ 'n', 'x' }, '<F3>', function() vim.lsp.buf.format({ async = true }) end, vim.tbl_extend('force', opts, { desc = 'LSP: Format' }))
    map('n', '<F4>', vim.lsp.buf.code_action, vim.tbl_extend('force', opts, { desc = 'LSP: Code Action' }))
  end,
})

-- ============================================================================
-- TREESITTER INCREMENTAL SELECTION
-- ============================================================================

-- Enhanced text selection with treesitter
map('n', '<Leader>v', function()
  require('nvim-treesitter.incremental_selection').init_selection()
end, { desc = 'Start incremental selection' })

map('x', ']x', function()
  require('nvim-treesitter.incremental_selection').node_incremental()
end, { desc = 'Expand selection to next node' })

map('x', '[x', function()
  require('nvim-treesitter.incremental_selection').node_decremental()
end, { desc = 'Shrink selection to previous node' })

-- ============================================================================
-- COMMENTING (Comment.nvim or built-in)
-- ============================================================================

-- Note: <C-/> is often interpreted as <C-_> in terminals
-- Map both variations to ensure compatibility across different terminals
local comment_normal = function()
  return vim.v.count == 0 and '<Plug>(comment_toggle_linewise_current)' or '<Plug>(comment_toggle_linewise_count)'
end

local comment_visual = '<Plug>(comment_toggle_linewise_visual)'

-- Normal mode commenting
map('n', '<C-_>', comment_normal, { expr = true, desc = 'Toggle comment line' })
map('n', '<C-/>', comment_normal, { expr = true, desc = 'Toggle comment line' })

-- Visual mode commenting  
map('x', '<C-_>', comment_visual, { desc = 'Toggle comment selection' })
map('x', '<C-/>', comment_visual, { desc = 'Toggle comment selection' })

-- ============================================================================
-- FLASH.NVIM SEARCH ENHANCEMENT
-- ============================================================================

-- Flash jump (only 's' key, f/F/t/T remain default vim behavior)
map({ 'n', 'x', 'o' }, 's', function()
  require('flash').jump()
end, { desc = 'Flash jump to location' })
