local function extend_unique(list, values)
  list = list or {}
  local seen = {}
  for _, value in ipairs(list) do
    seen[value] = true
  end
  for _, value in ipairs(values) do
    if not seen[value] then
      table.insert(list, value)
      seen[value] = true
    end
  end
  return list
end

local function strip_ansi(value)
  return value:gsub("\27%[[%d;]*m", "")
end

local function find_root_config(names)
  local filename = vim.api.nvim_buf_get_name(0)
  if filename == "" then
    return nil
  end
  return vim.fs.find(names, {
    path = vim.fs.dirname(filename),
    upward = true,
    type = "file",
  })[1]
end

return {
  -- Match the Cursor Stylelint extension with diagnostics/code-actions, and keep
  -- Stylelint's autofix available as a Conform formatter for CSS-family files.
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = extend_unique(opts.ensure_installed, {
        "stylelint",
        "stylelint-language-server",
        "mypy",
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        stylelint_lsp = {
          filetypes = {
            "astro",
            "css",
            "html",
            "less",
            "postcss",
            "scss",
            "vue",
          },
          settings = {
            stylelint = {
              validate = { "css", "less", "postcss", "scss" },
              snippet = { "css", "less", "postcss", "scss" },
            },
          },
        },
      },
    },
  },

  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.css = extend_unique(opts.formatters_by_ft.css, { "stylelint" })
      opts.formatters_by_ft.less = extend_unique(opts.formatters_by_ft.less, { "stylelint" })
      opts.formatters_by_ft.postcss = extend_unique(opts.formatters_by_ft.postcss, { "stylelint" })
      opts.formatters_by_ft.scss = extend_unique(opts.formatters_by_ft.scss, { "stylelint" })
    end,
  },

  -- Cursor maps *.eta to EJS and runs linthtml with a project config. Keep the
  -- same file association on the Neovim side so nvim-lint can pick it up.
  {
    "LazyVim/LazyVim",
    init = function()
      vim.filetype.add({
        extension = {
          eta = "ejs",
        },
      })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      -- Mypy can be expensive; avoid LazyVim's default InsertLeave lint trigger
      -- once Python type-checking is enabled.
      opts.events = { "BufWritePost", "BufReadPost" }

      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.python = extend_unique(opts.linters_by_ft.python, { "mypy" })
      opts.linters_by_ft.html = extend_unique(opts.linters_by_ft.html, { "linthtml" })
      opts.linters_by_ft.ejs = extend_unique(opts.linters_by_ft.ejs, { "linthtml" })
      opts.linters_by_ft.eta = extend_unique(opts.linters_by_ft.eta, { "linthtml" })

      opts.linters = opts.linters or {}
      opts.linters.linthtml = {
        cmd = "sh",
        stdin = false,
        append_fname = false,
        stream = "both",
        ignore_exitcode = true,
        args = {
          "-c",
          table.concat({
            "set -eu",
            "file=$1",
            "config=${2:-}",
            "if [ -x ./node_modules/.bin/linthtml ]; then bin=./node_modules/.bin/linthtml;",
            "elif command -v linthtml >/dev/null 2>&1; then bin=linthtml;",
            "else bin='npx --yes @linthtml/linthtml'; fi",
            'if [ -n "$config" ]; then exec $bin --config "$config" "$file"; fi',
            'exec $bin "$file"',
          }, "\n"),
          "linthtml",
          function()
            return vim.api.nvim_buf_get_name(0)
          end,
          function()
            local ft = vim.bo.filetype
            if ft == "ejs" or ft == "eta" then
              return find_root_config({ ".linthtmlrc.eta.json", ".linthtmlrc.eta.js", ".linthtmlrc.eta.cjs" }) or ""
            end
            return ""
          end,
        },
        parser = function(output)
          local severities = {
            error = vim.diagnostic.severity.ERROR,
            warning = vim.diagnostic.severity.WARN,
          }
          local diagnostics = {}

          for line in strip_ansi(output):gmatch("[^\r\n]+") do
            local lnum, col, severity, message, code =
              line:match("^%s*([%d%-]+):([%d%-]+)%s+(%w+)%s+(.-)%s+([%w%-_]+)%s*$")
            if not lnum then
              lnum, col, severity, message = line:match("^%s*([%d%-]+):([%d%-]+)%s+(%w+)%s+(.+)%s*$")
            end

            if severity and severities[severity] then
              lnum = tonumber(lnum) or 1
              col = tonumber(col) or 1
              table.insert(diagnostics, {
                lnum = math.max(lnum - 1, 0),
                col = math.max(col - 1, 0),
                message = message,
                code = code,
                severity = severities[severity],
                source = "linthtml",
                user_data = {
                  lsp = {
                    code = code,
                  },
                },
              })
            end
          end

          return diagnostics
        end,
      }
    end,
  },
}
