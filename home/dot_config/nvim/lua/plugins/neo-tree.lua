return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      filesystem = {
        -- Show dotfiles and gitignored files by default. This is the whole
        -- point of the override: a dotfiles repo is unusable when neo-tree
        -- hides everything that starts with a dot.
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
          hide_hidden = false, -- Windows only, harmless elsewhere
          never_show = {
            ".DS_Store",
            "thumbs.db",
          },
        },
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
      },
      window = {
        width = 34,
        mappings = {
          -- Toggle the filter back on when the noise gets in the way.
          ["H"] = "toggle_hidden",
        },
      },
    },
  },
}
