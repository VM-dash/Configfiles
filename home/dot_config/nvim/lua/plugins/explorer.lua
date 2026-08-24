-- Snacks explorer is LazyVim's default file tree and owns <leader>e.
-- neo-tree used to be installed alongside it, so starting nvim on a
-- directory opened TWO explorers; it is removed — this is the only one.
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            -- Show dotfiles and gitignored files by default. This is the
            -- whole point of the override: a dotfiles repo is unusable when
            -- the explorer hides everything that starts with a dot.
            -- Toggle live from inside the explorer: <a-h> hidden, <a-i> ignored.
            hidden = true,
            ignored = true,
          },
        },
      },
    },
  },
}
