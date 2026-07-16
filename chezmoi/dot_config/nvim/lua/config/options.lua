-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.lazyvim_python_lsp = "pyright"
vim.g.lazyvim_python_ruff = "ruff"
vim.g.lazyvim_ts_lsp = "vtsls"
vim.g.lazyvim_picker = "telescope"

-- Bridge Neovim's +/* registers to the Windows clipboard when running under WSL.
-- The built-in tmux provider is detected in this environment, but it does not
-- reliably reach the host system clipboard from inside tmux.
if vim.fn.has("wsl") == 1 and vim.fn.executable("clip.exe") == 1 and vim.fn.executable("powershell.exe") == 1 then
  local function copy_to_windows_clipboard(lines, regtype)
    local text = table.concat(lines, "\n")
    if regtype == "V" then
      text = text .. "\n"
    end
    vim.fn.system({ "clip.exe" }, text)
  end

  local function paste_from_windows_clipboard()
    local text = vim.fn
      .system({ "powershell.exe", "-NoLogo", "-NoProfile", "-Command", "Get-Clipboard -Raw" })
      :gsub("\r\n", "\n")
      :gsub("\r", "\n")
    local regtype = text:sub(-1) == "\n" and "V" or "v"
    if regtype == "V" then
      text = text:sub(1, -2)
    end
    return vim.split(text, "\n", { plain = true }), regtype
  end

  vim.g.clipboard = {
    name = "WslClipboard",
    copy = {
      ["+"] = copy_to_windows_clipboard,
      ["*"] = copy_to_windows_clipboard,
    },
    paste = {
      ["+"] = paste_from_windows_clipboard,
      ["*"] = paste_from_windows_clipboard,
    },
    cache_enabled = 0,
  }
end

-- Make normal yanks/deletes/pastes use the system clipboard by default. LazyVim
-- temporarily clears this option during startup, so re-apply it after startup too.
local function use_system_clipboard()
  vim.opt.clipboard = "unnamedplus"
end

use_system_clipboard()
vim.schedule(use_system_clipboard)
vim.api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
  group = vim.api.nvim_create_augroup("UserSystemClipboard", { clear = true }),
  callback = use_system_clipboard,
})
vim.api.nvim_create_autocmd("User", {
  group = "UserSystemClipboard",
  pattern = "VeryLazy",
  callback = use_system_clipboard,
})

-- Use absolute line numbers instead of LazyVim's default relative numbers.
vim.opt.number = true
vim.opt.relativenumber = false
