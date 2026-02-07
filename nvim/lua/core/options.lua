local opt = vim.opt
local g = vim.g

-- Set mapleader (ensure this is done early)
g.mapleader = "\\"
g.maplocalleader = "\\"

-- Editor behavior
opt.number = true           -- Show line numbers
opt.relativenumber = true   -- Show relative line numbers

opt.tabstop = 4             -- Number of spaces a <Tab> counts for
opt.softtabstop = 4         -- Number of spaces to insert/delete when <Tab>/<BS> is used
opt.shiftwidth = 4          -- Number of spaces for autoindent
opt.expandtab = true        -- Use spaces instead of tabs
opt.autoindent = true       -- Copy indent from current line when starting a new line
opt.foldlevel = 99          -- start all files with all folds opened

-- Searching
opt.incsearch = true        -- Show search results incrementally
opt.hlsearch = true         -- Highlight search results
opt.ignorecase = true       -- Ignore case in search patterns
opt.smartcase = true        -- Override 'ignorecase' if search pattern contains uppercase letters

-- Performance
opt.lazyredraw = true       -- Don't redraw screen during macros/scripts
opt.ttyfast = true          -- Indicates a fast terminal connection

-- Files and backups
opt.swapfile = true         -- Create a swapfile
opt.backup = false          -- Do not create a backup file
opt.undodir = vim.fn.stdpath("data") .. "/undodir" -- Set undo directory
opt.undofile = true         -- Save undo history to file

-- UI
opt.termguicolors = true    -- Enable 24-bit RGB color in the TUI
opt.scrolloff = 8           -- Minimum number of screen lines to keep above/below cursor
opt.sidescrolloff = 8       -- Minimum number of screen columns to keep to the left/right of cursor
opt.wrap = false            -- Do not wrap lines

opt.showmatch = true        -- Show matching brackets
opt.ruler = true            -- Show cursor position
opt.colorcolumn = "80"

-- Clipboard (already good)
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"

-- Timeouts
opt.timeoutlen = 500        -- Time in milliseconds to wait for a mapped sequence
opt.ttimeoutlen = 0         -- Time in milliseconds to wait for a key code sequence (0 for faster Esc)

-- Enable syntax highlighting (though Treesitter will primarily handle this)
-- vim.cmd("syntax on") -- This is often enabled by default or by colorschemes/treesitter

-- ============================================================================
-- TERMINAL TITLE (Shows filename in terminal tab, e.g., ghostty)
-- ============================================================================
opt.title = true
opt.titlestring = '%t%( %M%)%( (%{expand("%:~:.:h")})%)%( %a%)'
-- Format: filename [modified] (relative_path) [args]
-- Example: "main.qmd ● (manuscript)" or "keymaps.lua (lua/core)"

-- Alternative simpler format:
-- opt.titlestring = 'nvim: %t%( %M%)'  -- "nvim: filename ●"
