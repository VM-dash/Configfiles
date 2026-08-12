-- Loaded by LazyVim after its own autocmds.

local augroup = vim.api.nvim_create_augroup("UserConfig", { clear = true })

-- Briefly highlight whatever was just yanked.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})

-- Re-apply the colorscheme when the system theme changes underneath a running
-- instance. `theme` also pushes a reload over the RPC socket; this covers the
-- case where the file changed while Neovim was suspended or backgrounded.
vim.api.nvim_create_autocmd("FocusGained", {
  group = augroup,
  callback = function()
    local theme = require("config.theme")
    if vim.g.colors_name ~= theme.current() then
      theme.apply()
    end
  end,
})

-- Trim trailing whitespace on save, except where it is significant.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(event)
    local ft = vim.bo[event.buf].filetype
    if ft == "markdown" or ft == "diff" then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})
