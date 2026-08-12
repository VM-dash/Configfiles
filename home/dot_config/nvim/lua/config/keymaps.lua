-- Loaded by LazyVim after its own keymaps, so anything here wins.

local map = vim.keymap.set

-- Keep the cursor centred when jumping through search results and half-pages.
map("n", "n", "nzzzv", { desc = "Next search result (centred)" })
map("n", "N", "Nzzzv", { desc = "Prev search result (centred)" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centred)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centred)" })

-- Paste over a selection without clobbering the unnamed register.
map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })

-- Move the selected lines up/down, re-indenting as they go.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Clear search highlight.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Theme: cycle through the shared catalog from inside Neovim. Runs the same
-- `theme` binary the shell uses, so every other app follows along.
map("n", "<leader>ut", function()
  vim.system({ "theme", "next", "--quiet" }, { text = true }, function()
    vim.schedule(function()
      require("config.theme").reload()
    end)
  end)
end, { desc = "Next theme (system-wide)" })
