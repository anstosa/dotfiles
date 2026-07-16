return {
  {
    "folke/snacks.nvim",
    opts = function()
      local delta_config = {
        git = {
          pagers = {
            {
              colorArg = "always",
              pager = "delta --dark --paging=never",
            },
          },
        },
      }

      local function git_root()
        local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
        return vim.v.shell_error == 0 and root or vim.fn.getcwd()
      end

      local function git_delta(args)
        args = args or ""
        local cmd = "git --no-pager diff --color=always " .. args .. " | delta --dark --paging=always"
        Snacks.terminal({ "sh", "-lc", cmd }, {
          cwd = git_root(),
          auto_close = false,
          win = {
            title = " git delta ",
          },
        })
      end

      vim.api.nvim_create_user_command("LazyGit", function(command)
        local opts = {
          config = delta_config,
        }
        if command.args ~= "" then
          opts.args = vim.split(command.args, " ")
        end
        Snacks.lazygit(opts)
      end, {
        force = true,
        nargs = "*",
        desc = "Open Lazygit",
      })

      vim.api.nvim_create_user_command("GitDelta", function(command)
        git_delta(command.args)
      end, {
        nargs = "*",
        desc = "Show git diff with delta",
      })

      vim.api.nvim_create_user_command("GitDeltaCached", function(command)
        git_delta("--cached " .. command.args)
      end, {
        nargs = "*",
        desc = "Show staged git diff with delta",
      })
    end,
  },
}
