-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Use the system clipboard for everyday yank/paste operations.
vim.keymap.set({ "n", "x" }, "y", '"+y', { desc = "Yank to System Clipboard" })
vim.keymap.set("n", "Y", '"+Y', { desc = "Yank Line to System Clipboard" })
vim.keymap.set({ "n", "x" }, "p", '"+p', { desc = "Paste from System Clipboard" })
vim.keymap.set({ "n", "x" }, "P", '"+P', { desc = "Paste Before from System Clipboard" })

-- App-style shortcuts.
vim.keymap.set("n", "<C-e>", function()
  Snacks.explorer({ cwd = LazyVim.root() })
end, { desc = "Explorer Snacks (Root Dir)" })

vim.keymap.set("n", "<C-p>", LazyVim.pick("files"), { desc = "Find Files (Root Dir)" })
vim.keymap.set("n", "<F12>", "gd", { desc = "Goto Definition", remap = true })
vim.keymap.set("n", "<C-S-p>", LazyVim.pick("commands"), { desc = "Command Palette" })
vim.keymap.set("n", "<M-p>", LazyVim.pick("commands"), { desc = "Command Palette" })

vim.keymap.set("n", "<C-r>", function()
  require("telescope.builtin").lsp_document_symbols()
end, { desc = "Find Symbols (Current File)" })

vim.keymap.set("n", "<C-S-F>", LazyVim.pick("live_grep"), { desc = "Global Search (Root Dir)" })

vim.keymap.set("n", "<C-S-H>", function()
  require("grug-far").open({
    transient = true,
    prefills = {
      paths = LazyVim.root(),
    },
  })
end, { desc = "Global Replace (Root Dir)" })

local function reload_config()
  local config_dir = vim.fn.stdpath("config")

  for name in pairs(package.loaded) do
    if name:match("^config%.") or name:match("^plugins%.") then
      package.loaded[name] = nil
    end
  end

  vim.cmd.source(vim.env.MYVIMRC)
  vim.cmd.source(config_dir .. "/lua/config/options.lua")
  vim.cmd.source(config_dir .. "/lua/config/autocmds.lua")
  vim.cmd.source(config_dir .. "/lua/config/keymaps.lua")

  vim.notify("Neovim config reloaded", vim.log.levels.INFO, { title = "Config" })
end

vim.keymap.set("n", "<C-S-r>", reload_config, { desc = "Reload Neovim Config" })
vim.keymap.set("n", "<M-r>", reload_config, { desc = "Reload Neovim Config" })
