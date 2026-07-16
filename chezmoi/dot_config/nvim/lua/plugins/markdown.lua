local function add_treesitter_parsers(opts, parsers)
  opts.ensure_installed = opts.ensure_installed or {}

  local installed = {}
  for _, parser in ipairs(opts.ensure_installed) do
    installed[parser] = true
  end

  for _, parser in ipairs(parsers) do
    if not installed[parser] then
      table.insert(opts.ensure_installed, parser)
      installed[parser] = true
    end
  end
end

return {
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {
      file_types = { "markdown" },
    },
  },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      add_treesitter_parsers(opts, {
        "markdown",
        "markdown_inline",
      })
    end,
  },
}
