-- find git root
local function git_root()
  local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  -- require git success
  if vim.v.shell_error == 0 and root and root ~= "" then
    return root
  end
  return nil
end

-- check ref existence
local function ref_exists(ref)
  vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", ref })
  return vim.v.shell_error == 0
end

-- choose default base
local function default_base()
  -- scan common branch refs
  for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    -- use first existing ref
    if ref_exists(ref) then
      return ref
    end
  end
  return "HEAD~1"
end

local review_pathspecs = { "." }

-- Review the complete branch state, including tests and all other non-ignored
-- files. The cockpit guide and Diffview must agree on the reviewed scope.
local review_excluded_pathspecs = {}

-- build diffview args
local function review_args(range)
  local args = { range, "--" }
  vim.list_extend(args, review_pathspecs)
  vim.list_extend(args, review_excluded_pathspecs)
  return args
end

-- build focused file diff args
local function review_file_args(range, path)
  return { range, "--", path }
end

local review_diff_highlights = {
  DiffAdd = { bg = "#15351f", fg = "#b7f7c4" },
  DiffChange = { bg = "#343018", fg = "#f7df8a" },
  DiffDelete = { bg = "#3c1820", fg = "#ffb7c5" },
  DiffText = { bg = "#634b16", fg = "#fff2b3", bold = true },
}

-- apply review diff colors
local function apply_review_diff_highlights()
  -- set each diff group
  for group, spec in pairs(review_diff_highlights) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- select command base
local function command_base(opts)
  local env_base = vim.env.REVIEW_COCKPIT_BASE
  -- prefer explicit command args
  if opts.args ~= "" then
    return opts.args
  end
  -- prefer safe shell env
  if env_base and env_base ~= "" then
    return env_base
  end
  -- use default base
  return default_base()
end


-- keep diff windows locked
local function sync_diff_scroll()
  -- diffview enables this itself, but make it explicit so every review window
  -- keeps lockstep scrolling after layout changes
  vim.wo.diff = true
  vim.wo.scrollbind = true
  vim.wo.cursorbind = true
  vim.o.scrollopt = "ver,hor,jump"
end

-- sync diffview layout
local function sync_view_layout(view)
  -- sync only when diffview exposes layout hook
  if view and view.cur_layout and view.cur_layout.sync_scroll then
    pcall(function()
      -- invoke diffview sync
      view.cur_layout:sync_scroll()
    end)
  end
end

-- open raw branch review
local function review_branch(opts)
  local cwd = git_root()
  -- require git context
  if not cwd then
    vim.notify("ReviewBranch must be run inside a git repository", vim.log.levels.ERROR)
    return
  end

  local base = command_base(opts)
  -- A single merge-base revision makes Diffview compare it with the current
  -- working tree, so staged and unstaged edits appear alongside branch commits.
  local range = vim.fn.systemlist({ "git", "merge-base", base, "HEAD" })[1]
  if vim.v.shell_error ~= 0 or not range or range == "" then
    vim.notify("ReviewBranch could not resolve the merge base for " .. base, vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_cmd({ cmd = "DiffviewOpen", args = review_args(range) }, {})
  vim.schedule(function()
    -- notify raw range
    vim.notify("Reviewing " .. range, vim.log.levels.INFO, { title = "Diffview" })
  end)
end

-- open guided review cockpit
local function review_cockpit(opts)
  require("ansel.review_cockpit").open(opts, {
    default_base = default_base,
    review_args = review_args,
    review_file_args = review_file_args,
    pathspecs = review_pathspecs,
    excluded_pathspecs = review_excluded_pathspecs,
  })
end

return {
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewFileHistory",
      "ReviewBranch",
      "ReviewCockpit",
      "ReviewCockpitMarkReviewed",
      "ReviewCockpitOpenFileDiff",
      "ReviewCockpitToggleInline",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      { "<leader>gR", "<cmd>ReviewCockpit<cr>", desc = "Review Cockpit" },
      { "<leader>gI", "<cmd>ReviewCockpitToggleInline<cr>", desc = "Toggle Review Inline Notes" },
      { "<leader>gr", "<cmd>ReviewBranch<cr>", desc = "Review Branch Raw" },
      { "<leader>gD", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Current File History" },
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      hooks = {
        diff_buf_win_enter = function()
          -- enable scroll sync
          sync_diff_scroll()
          require("ansel.review_cockpit").bind_return_to_guide(0)
        end,
        view_post_layout = function(view)
          -- resync view layout
          sync_view_layout(view)
        end,
      },
    },
    config = function(_, opts)
      -- configure diffview
      require("diffview").setup(opts)
      -- improve review diffs
      apply_review_diff_highlights()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("ReviewDiffHighlights", { clear = true }),
        callback = function()
          -- reapply review diff colors
          apply_review_diff_highlights()
        end,
      })
      vim.api.nvim_create_user_command("ReviewBranch", review_branch, {
        nargs = "?",
        desc = "Open Diffview for the current branch against a base ref",
      })
      vim.api.nvim_create_user_command("ReviewCockpit", review_cockpit, {
        nargs = "?",
        desc = "Open guided review cockpit for the current branch against a base ref",
      })
      vim.api.nvim_create_user_command("ReviewCockpitMarkReviewed", function(opts)
        -- mark reviewed progress
        require("ansel.review_cockpit").mark_reviewed(opts)
      end, {
        nargs = "?",
        complete = "file",
        desc = "Mark the current or supplied review file as reviewed",
      })
      vim.api.nvim_create_user_command("ReviewCockpitOpenFileDiff", function(opts)
        -- open selected file diff
        require("ansel.review_cockpit").open_file_diff(opts)
      end, {
        nargs = "?",
        complete = "file",
        desc = "Open Diffview for the current review guide file",
      })
      vim.api.nvim_create_user_command("ReviewCockpitToggleInline", function()
        -- toggle inline notes
        require("ansel.review_cockpit").toggle_inline()
      end, {
        desc = "Toggle guided review notes inside diff buffers",
      })
    end,
  },

  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      -- disable lazyvim/snacks smooth scrolling
      -- keep diffview scrollbind predictable
      opts.scroll = { enabled = false }
      opts.gh = opts.gh or {}
      opts.picker = opts.picker or {}
      opts.picker.sources = opts.picker.sources or {}
      opts.picker.sources.gh_pr = opts.picker.sources.gh_pr or {}
    end,
    keys = {
      { "<leader>gp", function() Snacks.picker.gh_pr() end, desc = "GitHub Pull Requests" },
      { "<leader>gP", function() Snacks.picker.gh_pr({ state = "all" }) end, desc = "GitHub Pull Requests (all)" },
    },
  },
}
