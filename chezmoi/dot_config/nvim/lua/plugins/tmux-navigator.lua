local function set_diffview_tmux_navigation(bufnr)
  local maps = {
    { "<C-h>", "<cmd><C-U>TmuxNavigateLeft<cr>", "Navigate Left (Diffview/tmux)" },
    { "<C-j>", "<cmd><C-U>TmuxNavigateDown<cr>", "Navigate Down (Diffview/tmux)" },
    { "<C-k>", "<cmd><C-U>TmuxNavigateUp<cr>", "Navigate Up (Diffview/tmux)" },
    { "<C-l>", "<cmd><C-U>TmuxNavigateRight<cr>", "Navigate Right (Diffview/tmux)" },
    { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", "Navigate Previous (Diffview/tmux)" },
  }

  for _, map in ipairs(maps) do
    vim.keymap.set("n", map[1], map[2], {
      buffer = bufnr,
      desc = map[3],
      nowait = true,
      silent = true,
    })
  end
end

return {
  {
    "christoomey/vim-tmux-navigator",
    init = function()
      -- The plugin defaults to Ctrl+h/j/k/l. Keep pane navigation on
      -- Ctrl+Arrow globally so normal shell/Vim Ctrl+h/j/k/l behavior is untouched,
      -- but enable Ctrl+h/j/k/l inside Diffview review panes.
      vim.g.tmux_navigator_no_mappings = 1

      local group = vim.api.nvim_create_augroup("diffview_tmux_navigation", { clear = true })

      -- Diff panes keep the underlying filetype, so use Diffview's User event.
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "DiffviewDiffBufWinEnter",
        callback = function()
          set_diffview_tmux_navigation(vim.api.nvim_get_current_buf())
        end,
      })

      -- The file list panel has its own filetype.
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = "DiffviewFiles",
        callback = function(event)
          set_diffview_tmux_navigation(event.buf)
        end,
      })
    end,
    cmd = {
      "TmuxNavigateLeft",
      "TmuxNavigateDown",
      "TmuxNavigateUp",
      "TmuxNavigateRight",
      "TmuxNavigatePrevious",
      "TmuxNavigatorProcessList",
    },
    keys = {
      { "<C-Left>", "<cmd><C-U>TmuxNavigateLeft<cr>", desc = "Navigate Left (Vim/tmux)" },
      { "<C-Down>", "<cmd><C-U>TmuxNavigateDown<cr>", desc = "Navigate Down (Vim/tmux)" },
      { "<C-Up>", "<cmd><C-U>TmuxNavigateUp<cr>", desc = "Navigate Up (Vim/tmux)" },
      { "<C-Right>", "<cmd><C-U>TmuxNavigateRight<cr>", desc = "Navigate Right (Vim/tmux)" },
      { "<C-\\>", "<cmd><C-U>TmuxNavigatePrevious<cr>", desc = "Navigate Previous (Vim/tmux)" },
    },
  },
}
