-- All Catppuccin flavours and all Rose Pine variants are installed at once;
-- which one is active comes from ~/.config/theme/current via config.theme.

return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      -- flavour is not pinned here: config.theme picks the concrete
      -- colorscheme name (catppuccin-mocha, catppuccin-latte, ...).
      term_colors = true,
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      -- neotree/telescope/which_key/mason are already on via
      -- default_integrations; only the undercurl override is a real delta.
      integrations = {
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
    },
  },

  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000,
    opts = {
      -- variant is chosen by colorscheme name (rose-pine-main / -moon / -dawn).
      styles = { italic = true },
    },
  },

  -- Hand the choice to config.theme instead of hardcoding a name, so the
  -- system-wide switcher stays the single source of truth.
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        require("config.theme").apply()
      end,
    },
  },
}
