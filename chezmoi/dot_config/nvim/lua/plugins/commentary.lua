return {
  {
    "tpope/vim-commentary",
    lazy = false,
    config = function()
      -- Keep gcc as a direct command so which-key's g/gc menus don't turn the
      -- final c into an operator-pending "change" motion.
      vim.keymap.set("n", "gcc", "<cmd>Commentary<cr>", { desc = "Comment line", silent = true })
      vim.keymap.set({ "n", "x", "o" }, "gc", "<Plug>Commentary", { desc = "Commentary", remap = true })
      vim.keymap.set("n", "gcu", "<Plug>Commentary<Plug>Commentary", { desc = "Uncomment line", remap = true })

      pcall(function()
        require("which-key").add({
          { "gc", group = "comment" },
          { "gcc", desc = "Comment line" },
          { "gcu", desc = "Uncomment line" },
        }, { mode = "n" })
      end)
    end,
  },
}
