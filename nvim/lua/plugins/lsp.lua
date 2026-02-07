return {
	{
    'mason-org/mason.nvim',
    tag = 'v1.11.0',
    pin = true,
    lazy = false,
    opts = {
      ensure_installed = {
        "ty",
        "ruff",
      },
    },
  },
  {
    'mason-org/mason-lspconfig.nvim',
    tag = 'v1.32.0',
    pin = true,
    lazy = true,
    config = false,
  },

  -- Autocompletion
  {
    'hrsh7th/nvim-cmp',
    event = 'InsertEnter',
    config = function()
      local cmp = require('cmp')

      cmp.setup({
        sources = {
          {name = 'nvim_lsp'},
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-u>'] = cmp.mapping.scroll_docs(-4),
          ['<C-d>'] = cmp.mapping.scroll_docs(4),

          -- UPDATED: Arrow keys for navigation
          ['<Down>'] = cmp.mapping.select_next_item(),
          ['<Up>'] = cmp.mapping.select_prev_item(),

          -- UPDATED: Tab to confirm and insert completion
          ['<Tab>'] = cmp.mapping.confirm({ select = true }),

          -- Enter also confirms completion (alternative to Tab)
          ['<CR>'] = cmp.mapping.confirm({ select = true }),

          -- Escape to close completion menu
          ['<Esc>'] = cmp.mapping.abort(),
        }),
        snippet = {
          expand = function(args)
            vim.snippet.expand(args.body)
          end,
        },
      })
    end
  },

  -- LSP
  {
    'neovim/nvim-lspconfig',
    tag = 'v1.8.0',
    pin = true,
    cmd = {'LspInfo', 'LspInstall', 'LspStart'},
    event = {'BufReadPre', 'BufNewFile'},
    dependencies = {
      {'hrsh7th/cmp-nvim-lsp'},
      {'mason-org/mason.nvim'},
      {'mason-org/mason-lspconfig.nvim'},
    },
    init = function()
      -- Reserve a space in the gutter
      -- This will avoid an annoying layout shift in the screen
      vim.opt.signcolumn = 'yes'
    end,
    config = function()
      local lsp_defaults = require('lspconfig').util.default_config

      -- Add cmp_nvim_lsp capabilities settings to lspconfig
      -- This should be executed before you configure any language server
      lsp_defaults.capabilities = vim.tbl_deep_extend(
        'force',
        lsp_defaults.capabilities,
        require('cmp_nvim_lsp').default_capabilities()
      )

      -- ty: Type checking + intellisense (Astral.sh)
      -- Using native Neovim 0.11+ API (ty.lua is in lsp/ not lua/lspconfig/configs/)
      vim.lsp.config('ty', {
        settings = {
          ty = {
            inlayHints = {
              variableTypes = true,
              callArgumentNames = true,
            },
            completions = {
              autoImport = true,
            },
            diagnosticMode = "openFilesOnly",
          }
        }
      })
      vim.lsp.enable('ty')

      -- Disable ruff hover (ty handles intellisense)
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup('lsp_disable_ruff_hover', { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == 'ruff' then
            client.server_capabilities.hoverProvider = false
          end
        end,
      })

      -- Format Python on save (useful for agent-generated code)
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*.py",
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })

      require('mason-lspconfig').setup({
        ensure_installed = {},
        handlers = {
          -- this first function is the "default handler"
          -- it applies to every language server without a "custom handler"
          function(server_name)
            require('lspconfig')[server_name].setup({})
          end,

          -- ruff: Linting + formatting (Astral.sh)
          ruff = function()
            require('lspconfig').ruff.setup({
              init_options = {
                settings = {
                  lineLength = 88,
                  lint = {
                    select = { "E", "F", "W", "I", "UP", "B", "SIM", "C4" },
                  },
                }
              }
            })
          end,
        }
      })
    end
  },
}
