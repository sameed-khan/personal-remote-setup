-- ============================================================================
-- Filetype Detection Configuration
-- Register custom filetypes and their associated file extensions
-- ============================================================================

-- Register Typst filetype for .typ files
vim.filetype.add({
  extension = {
    typ = "typst",
  },
})
