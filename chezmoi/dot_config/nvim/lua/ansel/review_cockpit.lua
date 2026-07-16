local M = {}

local current_session = nil
local inline_enabled = true
local inline_namespace = vim.api.nvim_create_namespace("review-cockpit-inline")
-- guide diff namespace
local guide_diff_namespace = vim.api.nvim_create_namespace("review-cockpit-guide-diff")

-- inline diff palette
local diff_highlights = {
  ReviewCockpitDiffAdd = { fg = "#7ee787", bold = true },
  ReviewCockpitDiffDelete = { fg = "#ff7b72", bold = true },
  ReviewCockpitDiffHunk = { fg = "#d29922", bold = true },
  ReviewCockpitDiffContext = { fg = "#8b949e" },
}

local required_top_level = {
  "schema_version",
  "generated_at",
  "repo_root",
  "base_ref",
  "head_ref",
  "range",
  "git_merge_base",
  "git_head",
  "includes_worktree",
  "markdown_path",
  "files",
  "checklist",
  "questions",
  "non_goals_enforced",
  "warnings",
  "pathspecs",
  "excluded_pathspecs",
}

local required_file_fields = {
  "path",
  "status",
  "additions",
  "deletions",
  "summary",
  "why",
  "risks",
  "diff_excerpt",
  "review_order",
}

-- apply cockpit colors
local function apply_review_highlights()
  -- set highlight groups
  for group, spec in pairs(diff_highlights) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- choose diff line color
local function diff_line_highlight(line)
  local trimmed = line:gsub("^%s+", "")
  -- highlight additions
  if trimmed:sub(1, 1) == "+" and trimmed:sub(1, 3) ~= "+++" then
    return "ReviewCockpitDiffAdd"
  end
  -- highlight deletions
  if trimmed:sub(1, 1) == "-" and trimmed:sub(1, 3) ~= "---" then
    return "ReviewCockpitDiffDelete"
  end
  -- highlight hunk headers
  if trimmed:sub(1, 2) == "@@" then
    return "ReviewCockpitDiffHunk"
  end
  return "ReviewCockpitDiffContext"
end

-- highlight guide diff blocks
local function apply_guide_diff_highlights(buf)
  apply_review_highlights()
  vim.api.nvim_buf_clear_namespace(buf, guide_diff_namespace, 0, -1)
  local in_diff_block = false
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- scan guide lines
  for index, line in ipairs(lines) do
    -- enter diff fence
    if line == "```diff" then
      in_diff_block = true
    -- leave any fence
    elseif in_diff_block and line == "```" then
      in_diff_block = false
    -- color diff content
    elseif in_diff_block and line ~= "" then
      vim.api.nvim_buf_set_extmark(buf, guide_diff_namespace, index - 1, 0, {
        end_row = index - 1,
        end_col = #line,
        hl_group = diff_line_highlight(line),
        hl_mode = "replace",
        priority = 2000,
      })
    end
  end
end

-- find git root
local function git_root()
  local root = vim.fn.systemlist({ "git", "rev-parse", "--show-toplevel" })[1]
  -- require git success
  if vim.v.shell_error == 0 and root and root ~= "" then
    return root
  end
  return nil
end

-- run git line
local function git_line(args)
  local output = vim.fn.systemlist(vim.list_extend({ "git" }, args))
  -- require git success
  if vim.v.shell_error == 0 and output[1] and output[1] ~= "" then
    return output[1]
  end
  return nil
end

-- build state fallback dir
local function home_state_dir(root)
  local state_home = vim.env.XDG_STATE_HOME
  -- default state home
  if not state_home or state_home == "" then
    state_home = vim.fn.expand("~/.local/state")
  end
  local digest = vim.fn.sha256(root):sub(1, 16)
  return state_home .. "/review-cockpit/" .. digest
end

-- check readable file
local function readable(path)
  return path and path ~= "" and vim.fn.filereadable(path) == 1
end

-- resolve latest symlink or file
local function resolve_readable(path)
  -- check direct path
  if readable(path) then
    return path
  end
  return nil
end

-- discover artifact path
local function discover_artifact(root)
  -- prefer explicit global
  if vim.g.review_cockpit_artifact and vim.g.review_cockpit_artifact ~= "" then
    return resolve_readable(vim.g.review_cockpit_artifact), "g:review_cockpit_artifact"
  end
  -- prefer environment
  if vim.env.REVIEW_COCKPIT_ARTIFACT and vim.env.REVIEW_COCKPIT_ARTIFACT ~= "" then
    return resolve_readable(vim.env.REVIEW_COCKPIT_ARTIFACT), "REVIEW_COCKPIT_ARTIFACT"
  end
  -- prefer repo git state
  if root then
    local repo_latest = root .. "/.git/review-cockpit/latest.json"
    -- use repo latest
    if readable(repo_latest) then
      return repo_latest, "repo latest"
    end
    local home_latest = home_state_dir(root) .. "/latest.json"
    -- use home latest
    if readable(home_latest) then
      return home_latest, "home latest"
    end
  end
  return nil, "not found"
end

-- compare arrays
local function same_list(actual, expected)
  -- require list tables
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  -- require same length
  if #actual ~= #expected then
    return false
  end
  -- compare items
  for index, value in ipairs(expected) do
    -- require exact item
    if actual[index] ~= value then
      return false
    end
  end
  return true
end

-- normalize path
local function normalize_path(path)
  local resolved = vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
  return resolved:gsub("/$", "")
end

-- collect validation errors
local function validate_artifact(artifact, expected)
  local errors = {}
  -- require object
  if type(artifact) ~= "table" then
    return { "artifact root is not an object" }
  end
  -- check schema version
  if artifact.schema_version ~= 1 then
    table.insert(errors, "schema_version must be 1")
  end
  -- check top-level fields
  for _, field in ipairs(required_top_level) do
    -- report missing field
    if artifact[field] == nil then
      table.insert(errors, "missing top-level field: " .. field)
    end
  end
  -- check selected range
  if artifact.range ~= expected.range then
    table.insert(errors, "artifact range " .. tostring(artifact.range) .. " does not match selected range " .. expected.range)
  end
  -- check current repo
  if artifact.repo_root and normalize_path(artifact.repo_root) ~= normalize_path(expected.root) then
    table.insert(errors, "artifact repo_root " .. tostring(artifact.repo_root) .. " does not match current repo " .. expected.root)
  end
  -- check selected base
  if artifact.base_ref ~= expected.base then
    table.insert(errors, "artifact base_ref " .. tostring(artifact.base_ref) .. " does not match selected base " .. expected.base)
  end
  -- check current head
  if artifact.git_head ~= expected.git_head then
    table.insert(errors, "artifact git_head " .. tostring(artifact.git_head) .. " does not match current HEAD " .. tostring(expected.git_head))
  end
  -- check current merge base
  if artifact.git_merge_base ~= expected.git_merge_base then
    table.insert(errors, "artifact git_merge_base " .. tostring(artifact.git_merge_base) .. " does not match current merge base " .. tostring(expected.git_merge_base))
  end
  -- check diff pathspecs
  if not same_list(artifact.pathspecs, expected.pathspecs) then
    table.insert(errors, "artifact pathspecs do not match Diffview pathspecs")
  end
  -- check diff exclusions
  if not same_list(artifact.excluded_pathspecs, expected.excluded_pathspecs) then
    table.insert(errors, "artifact excluded_pathspecs do not match Diffview exclusions")
  end
  -- check files list
  if type(artifact.files) ~= "table" then
    table.insert(errors, "files must be a list")
  else
    -- check file fields
    for index, file_info in ipairs(artifact.files) do
      -- validate file object
      if type(file_info) ~= "table" then
        table.insert(errors, "files[" .. index .. "] must be an object")
      else
        -- check required file keys
        for _, field in ipairs(required_file_fields) do
          -- report missing key
          if file_info[field] == nil then
            table.insert(errors, "files[" .. index .. "] missing field: " .. field)
          end
        end
      end
    end
  end
  return errors
end

-- read json artifact
local function read_artifact(path, expected)
  local ok, lines = pcall(vim.fn.readfile, path)
  -- handle read failure
  if not ok then
    return nil, { "failed to read artifact: " .. tostring(lines) }
  end
  local text = table.concat(lines, "\n")
  local decoded_ok, artifact = pcall(vim.json.decode, text)
  -- handle malformed json
  if not decoded_ok then
    return nil, { "malformed artifact JSON: " .. tostring(artifact) }
  end
  local errors = validate_artifact(artifact, expected)
  -- return validation errors
  if #errors > 0 then
    return nil, errors
  end
  return artifact, {}
end

-- write scratch lines
local function set_buffer_lines(buf, lines, filetype)
  vim.bo[buf].buftype = "nofile"
  -- Keep the guide available while a focused Diffview temporarily owns the tab.
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].textwidth = 120
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = filetype or "markdown"
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.colorcolumn = "120"
  apply_guide_diff_highlights(buf)
end

-- wipe named scratch buffers
local function wipe_named_buffer(name)
  -- scan existing buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- wipe matching cockpit buffer
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == name then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

-- open guide buffer
local function open_guide_buffer(name, lines, filetype)
  wipe_named_buffer(name)
  vim.cmd("enew")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_name(buf, name)
  set_buffer_lines(buf, lines, filetype)
  return buf
end

-- read guide markdown
local function guide_lines(artifact)
  -- prefer markdown path
  if artifact and readable(artifact.markdown_path) then
    local ok, lines = pcall(vim.fn.readfile, artifact.markdown_path)
    -- use guide file
    if ok then
      return lines
    end
  end
  return {
    "# Review cockpit guide unavailable",
    "",
    "The JSON artifact loaded, but its markdown_path could not be read.",
    "Press F12 on a file section to open the source diff.",
  }
end

-- format inline note lines
local function inline_lines_for_file(file_info)
  local lines = {
    file_info.summary,
    file_info.why ~= "" and file_info.why or "Unknown from deterministic git data.",
  }
  -- render risk summary
  if type(file_info.risks) == "table" and #file_info.risks > 0 then
    table.insert(lines, table.concat(file_info.risks, " | "))
  else
    table.insert(lines, "No obvious deterministic risk flags.")
  end
  -- render code excerpt
  if type(file_info.diff_excerpt) == "table" and #file_info.diff_excerpt > 0 then
    -- add excerpt lines
    for _, diff_line in ipairs(file_info.diff_excerpt) do
      table.insert(lines, "  " .. diff_line)
    end
  end
  table.insert(lines, "Actions: mr marks reviewed, q closes guide, :ReviewCockpitToggleInline hides these notes.")
  return lines
end

-- choose virtual line color
local function virtual_line_highlight(line)
  return diff_line_highlight(line)
end

-- convert text lines to virtual lines
local function virtual_lines(lines)
  local result = {}
  -- build extmark chunks
  for _, line in ipairs(lines) do
    table.insert(result, { { "  " .. line, virtual_line_highlight(line) } })
  end
  return result
end

-- match buffer to artifact file
local function buffer_matches_path(buf, root, file_path)
  local name = vim.api.nvim_buf_get_name(buf)
  -- require named buffer
  if name == "" then
    return false
  end
  local absolute = root .. "/" .. file_path
  -- match normal file buffer
  if name == absolute then
    return true
  end
  -- match diffview buffer variants
  if name:sub(-#absolute) == absolute then
    return true
  end
  -- match relative diffview suffix
  return name:find(file_path, 1, true) ~= nil
end

-- clear inline notes
local function clear_inline_notes()
  -- scan buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    -- clear valid buffers
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      vim.api.nvim_buf_clear_namespace(buf, inline_namespace, 0, -1)
    end
  end
end

-- apply inline notes
local function apply_inline_notes()
  apply_review_highlights()
  clear_inline_notes()
  -- require visible notes
  if not inline_enabled or not current_session or not current_session.artifact then
    return
  end
  -- scan artifact files
  for _, file_info in ipairs(current_session.artifact.files or {}) do
    -- scan buffers for matching file
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      -- annotate matching buffers
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and buffer_matches_path(buf, current_session.root, file_info.path) then
        vim.api.nvim_buf_set_extmark(buf, inline_namespace, 0, 0, {
          virt_lines = virtual_lines(inline_lines_for_file(file_info)),
          virt_lines_above = true,
        })
      end
    end
  end
end

-- install color refresh autocmd
local function install_highlight_autocmd()
  local group = vim.api.nvim_create_augroup("ReviewCockpitHighlights", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      -- refresh custom colors
      apply_review_highlights()
      -- scan loaded buffers
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        -- refresh guide buffers
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf):find("Review Cockpit", 1, true) then
          apply_guide_diff_highlights(buf)
        end
      end
    end,
  })
end

-- install inline refresh autocmd
local function install_inline_autocmd()
  local group = vim.api.nvim_create_augroup("ReviewCockpitInline", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufReadPost" }, {
    group = group,
    callback = function()
      -- refresh after diffview swaps buffers
      vim.schedule(apply_inline_notes)
    end,
  })
end

-- build warning guide
local function warning_lines(range, source, errors)
  local lines = {
    "# Review cockpit artifact unavailable",
    "",
    "Guide-only mode stayed open for `" .. range .. "`.",
    "",
    "Artifact source: " .. tostring(source),
    "",
    "## Why guided mode fell back",
  }
  -- render errors
  for _, error in ipairs(errors) do
    table.insert(lines, "- " .. error)
  end
  table.insert(lines, "")
  table.insert(lines, "## Generate artifacts")
  table.insert(lines, "")
  table.insert(lines, "Run `review [base]` from the shell, or run the bundled generator and set `REVIEW_COCKPIT_ARTIFACT`.")
  table.insert(lines, "")
  table.insert(lines, "No Diffview is opened until a valid guide is loaded and F12 is pressed on a file section.")
  return lines
end

-- path basename
local function basename(path)
  return vim.fn.fnamemodify(path, ":t")
end

-- progress sidecar name
local function progress_sidecar(path)
  -- require json
  if path and path:match("%.json$") then
    return path:gsub("%.json$", ".progress.json")
  end
  -- require markdown
  if path and path:match("%.md$") then
    return path:gsub("%.md$", ".progress.json")
  end
  return nil
end

-- resolve filesystem target
local function realpath(path)
  local fs_realpath = (vim.uv and vim.uv.fs_realpath) or (vim.loop and vim.loop.fs_realpath)
  -- require resolver
  if fs_realpath and path and path ~= "" then
    local ok, resolved = pcall(fs_realpath, path)
    -- use resolved target
    if ok and resolved and resolved ~= "" then
      return resolved
    end
  end
  return nil
end

-- choose approved state dir
local function approved_state_dir(root)
  local repo_state = root .. "/.git/review-cockpit"
  local ok = pcall(vim.fn.mkdir, repo_state, "p")
  local probe_path = repo_state .. "/.write-probe-" .. vim.fn.getpid()
  -- guard repo state probe
  local probe_ok, probe_result = pcall(vim.fn.writefile, { "" }, probe_path)
  -- require successful probe write
  local writable = ok and vim.fn.isdirectory(repo_state) == 1 and probe_ok and probe_result == 0
  -- remove write probe
  if writable then
    vim.fn.delete(probe_path)
  end
  -- prefer writable repo state
  if writable then
    return repo_state
  end
  local fallback_state = home_state_dir(root)
  -- ensure fallback state
  pcall(vim.fn.mkdir, fallback_state, "p")
  -- use home state fallback
  return fallback_state
end

-- progress path for artifact
local function progress_path(artifact, artifact_path, root)
  local state_dir = approved_state_dir(root)
  local resolved_path = realpath(artifact_path)
  -- prefer timestamped symlink target stem
  if resolved_path and resolved_path:match("%.json$") and basename(resolved_path) ~= "latest.json" then
    return progress_sidecar(state_dir .. "/" .. basename(resolved_path))
  end
  -- prefer artifact markdown stem
  if artifact and artifact.markdown_path and basename(artifact.markdown_path) ~= "latest.md" then
    local inferred = progress_sidecar(state_dir .. "/" .. basename(artifact.markdown_path))
    -- use inferred sidecar
    if inferred then
      return inferred
    end
  end
  -- use non-latest json sidecar name inside approved dir
  if artifact_path and artifact_path:match("%.json$") and basename(artifact_path) ~= "latest.json" then
    return progress_sidecar(state_dir .. "/" .. basename(artifact_path))
  end
  return state_dir .. "/review-cockpit.progress.json"
end

-- read progress state
local function read_progress(path)
  -- return empty for missing path
  if not readable(path) then
    return { reviewed = {}, updated_at = nil }
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  -- tolerate read errors
  if not ok then
    return { reviewed = {}, updated_at = nil }
  end
  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  -- tolerate malformed progress
  if not decoded_ok or type(decoded) ~= "table" then
    return { reviewed = {}, updated_at = nil }
  end
  decoded.reviewed = decoded.reviewed or {}
  return decoded
end

-- write progress state
local function write_progress(path, progress)
  progress.updated_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
  local encoded = vim.json.encode(progress)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile({ encoded }, path)
end

-- current file from diffview buffer
local function current_relative_path(root)
  local name = vim.api.nvim_buf_get_name(0)
  -- strip root prefix
  if root and name:sub(1, #root + 1) == root .. "/" then
    return name:sub(#root + 2)
  end
  return vim.fn.expand("%:p:.")
end

-- mark current file reviewed
local function mark_reviewed(root, progress_file, explicit_path)
  local progress = read_progress(progress_file)
  local path = explicit_path or current_relative_path(root)
  -- require path
  if not path or path == "" then
    vim.notify("ReviewCockpit: no current file to mark", vim.log.levels.WARN)
    return
  end
  progress.reviewed[path] = true
  write_progress(progress_file, progress)
  vim.notify("ReviewCockpit: marked reviewed: " .. path, vim.log.levels.INFO)
end

-- mark active cockpit file
function M.mark_reviewed(opts)
  -- require active session
  if not current_session then
    vim.notify("ReviewCockpit: no active progress file", vim.log.levels.WARN)
    return
  end
  local explicit_path = opts and opts.args ~= "" and opts.args or nil
  mark_reviewed(current_session.root, current_session.progress_file, explicit_path)
end

-- toggle inline notes
function M.toggle_inline()
  inline_enabled = not inline_enabled
  apply_inline_notes()
  vim.notify("ReviewCockpit: inline notes " .. (inline_enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

-- collect file-note headings only
local function file_note_lines(buf)
  local headings = {}
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Skip general guide sections and navigate only file-by-file notes.
  for index, line in ipairs(lines) do
    if line:match("^###%s+%d+%.%s+`") then
      table.insert(headings, index)
    end
  end
  return headings
end

-- jump between file notes
local function jump_file_note(buf, direction)
  local headings = file_note_lines(buf)
  -- require file notes
  if #headings == 0 then
    vim.notify("ReviewCockpit: no file notes found", vim.log.levels.WARN)
    return
  end
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  local target = headings[1]
  -- choose next file note
  if direction > 0 then
    -- scan forward
    for _, line_number in ipairs(headings) do
      -- use first later heading
      if line_number > current_line then
        target = line_number
        break
      end
    end
  else
    target = headings[#headings]
    -- scan backward
    for index = #headings, 1, -1 do
      -- use first earlier heading
      if headings[index] < current_line then
        target = headings[index]
        break
      end
    end
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  vim.cmd("normal! zt")
end

-- find file path in line
local function file_path_from_line(line, artifact)
  -- scan known files
  for _, file_info in ipairs(artifact.files or {}) do
    -- compare valid file records
    if type(file_info) == "table" and type(file_info.path) == "string" and file_info.path ~= "" then
      local ticked = "`" .. file_info.path .. "`"
      -- prefer exact markdown path
      if line:find(ticked, 1, true) then
        return file_info.path
      end
    end
  end
  return nil
end

-- resolve guide file under cursor
local function file_under_cursor(buf, artifact)
  -- require guide artifact
  if not artifact or type(artifact.files) ~= "table" then
    return nil
  end
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current = lines[cursor_line] or ""
  local direct = file_path_from_line(current, artifact)
  -- use direct cursor line
  if direct then
    return direct
  end
  -- scan containing file section
  for index = cursor_line, 1, -1 do
    local line = lines[index] or ""
    local path = file_path_from_line(line, artifact)
    -- use nearest path above cursor
    if path then
      return path
    end
    -- stop at top-level section boundary
    if line:match("^##%s+") then
      break
    end
  end
  return nil
end

-- build file diff args
local function file_diff_args(session, path)
  -- use working-tree diff
  if session.artifact and session.artifact.includes_worktree then
    return { session.artifact.git_merge_base, "-u=all", "--", path }
  end
  -- prefer configured helper
  if session.helpers and session.helpers.review_file_args then
    return session.helpers.review_file_args(session.range, path)
  end
  return { session.range, "--", path }
end

-- open selected file diff
function M.open_file_diff(opts)
  -- require active session
  if not current_session or not current_session.artifact then
    vim.notify("ReviewCockpit: no active guide artifact for F12", vim.log.levels.WARN)
    return
  end
  local explicit_path = nil
  -- accept command opts
  if type(opts) == "table" and opts.args and opts.args ~= "" then
    explicit_path = opts.args
  -- accept direct path
  elseif type(opts) == "string" and opts ~= "" then
    explicit_path = opts
  end
  local buf = type(opts) == "table" and opts.buf or vim.api.nvim_get_current_buf()
  local path = explicit_path or file_under_cursor(buf, current_session.artifact)
  -- require cursor file
  if not path or path == "" then
    vim.notify("ReviewCockpit: move the cursor onto a file section before pressing F12", vim.log.levels.WARN)
    return
  end
  -- Remember the guide position so the focused diff can return exactly here.
  current_session.guide_buf = buf
  current_session.guide_cursor = vim.api.nvim_win_get_cursor(0)
  vim.api.nvim_cmd({ cmd = "DiffviewOpen", args = file_diff_args(current_session, path) }, {})
  vim.schedule(function()
    -- Bind the return key in both diff panes and the temporary file-panel buffer.
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      M.bind_return_to_guide(vim.api.nvim_win_get_buf(win))
    end
    -- A focused review has exactly one file, so the Diffview file tree adds no value.
    local view = require("diffview.lib").get_current_view()
    if view and view.panel and view.panel:is_open() then
      view.panel:close()
    end
    -- refresh inline notes
    apply_inline_notes()
    vim.notify("ReviewCockpit: opened diff for " .. path, vim.log.levels.INFO, { title = "Diffview" })
  end)
  vim.defer_fn(function()
    -- refresh settled diff buffers
    apply_inline_notes()
  end, 150)
end

-- close the focused Diffview and restore the guide at its prior file note
function M.return_to_guide()
  if not current_session or not current_session.guide_buf or not vim.api.nvim_buf_is_valid(current_session.guide_buf) then
    vim.notify("ReviewCockpit: no guide to return to", vim.log.levels.WARN)
    return
  end
  local guide_buf = current_session.guide_buf
  local guide_cursor = current_session.guide_cursor
  pcall(vim.cmd, "DiffviewClose")
  vim.schedule(function()
    local guide_win = vim.fn.bufwinid(guide_buf)
    if guide_win ~= -1 then
      vim.api.nvim_set_current_win(guide_win)
    else
      vim.cmd("sbuffer " .. guide_buf)
    end
    if guide_cursor then
      vim.api.nvim_win_set_cursor(0, guide_cursor)
      vim.cmd("normal! zt")
    end
  end)
end

-- Bind both Neovim's shifted function-key notation and the F24 sequence that
-- terminals commonly emit for Shift+F12.
function M.bind_return_to_guide(buf)
  for _, key in ipairs({ "<S-F12>", "<F24>" }) do
    vim.keymap.set("n", key, M.return_to_guide, {
      buffer = buf,
      desc = "Close Diffview and return to review guide",
    })
  end
end

-- install guide keymaps
local function install_keymaps(buf, root, progress_file)
  vim.keymap.set("n", "<Tab>", function()
    -- jump forward by file note
    jump_file_note(buf, 1)
  end, { buffer = buf, desc = "Next review file" })
  vim.keymap.set("n", "<S-Tab>", function()
    -- jump backward by file note
    jump_file_note(buf, -1)
  end, { buffer = buf, desc = "Previous review file" })
  vim.keymap.set("n", "<F12>", function()
    -- open cursor file diff
    M.open_file_diff({ buf = buf })
  end, { buffer = buf, desc = "Open cursor file diff" })
  vim.keymap.set("n", "mr", function()
    -- require progress
    if not progress_file then
      vim.notify("ReviewCockpit: no progress file for this guide", vim.log.levels.WARN)
      return
    end
    -- prompt reviewed path
    local path = vim.fn.input("reviewed path: ")
    mark_reviewed(root, progress_file, path ~= "" and path or nil)
  end, { buffer = buf, desc = "Mark reviewed" })
  vim.keymap.set("n", "i", function()
    -- toggle inline notes
    M.toggle_inline()
  end, { buffer = buf, desc = "Toggle inline notes" })
  vim.keymap.set("n", "q", "<cmd>qa<cr>", { buffer = buf, desc = "Quit Neovim" })
end

-- open cockpit view
function M.open(opts, helpers)
  helpers = helpers or {}
  current_session = nil
  local env_base = vim.env.REVIEW_COCKPIT_BASE
  local base = nil
  -- prefer explicit command args
  if opts.args ~= "" then
    base = opts.args
  -- prefer safe shell env
  elseif env_base and env_base ~= "" then
    base = env_base
  -- use default base
  else
    base = helpers.default_base()
  end
  local range = base .. "...WORKTREE"
  local root = git_root()
  -- require git context
  if not root then
    vim.notify("ReviewCockpit must be run inside a git repository", vim.log.levels.ERROR)
    return
  end
  local expected = {
    root = root,
    base = base,
    range = range,
    git_head = git_line({ "rev-parse", "HEAD" }),
    git_merge_base = git_line({ "merge-base", base, "HEAD" }),
    pathspecs = helpers.pathspecs or { "." },
    excluded_pathspecs = helpers.excluded_pathspecs or {},
  }
  local artifact_path, source = discover_artifact(root)
  local artifact = nil
  local errors = {}
  -- load discovered artifact
  if artifact_path then
    artifact, errors = read_artifact(artifact_path, expected)
  else
    errors = { "no artifact found" }
  end
  local progress_file = artifact and progress_path(artifact, artifact_path, root) or nil
  -- expose progress only for valid guides
  if progress_file then
    current_session = { root = root, range = range, progress_file = progress_file, artifact = artifact, helpers = helpers }
  end
  install_inline_autocmd()
  install_highlight_autocmd()
  vim.schedule(function()
    -- open guide or warning
    if artifact then
      local buf = open_guide_buffer("Review Cockpit Guide", guide_lines(artifact), "markdown")
      install_keymaps(buf, root, progress_file)
      clear_inline_notes()
      vim.notify("ReviewCockpit: guide ready for " .. range .. " (F12 opens the cursor file diff)", vim.log.levels.INFO)
    else
      clear_inline_notes()
      local buf = open_guide_buffer("Review Cockpit Warning", warning_lines(range, source, errors), "markdown")
      install_keymaps(buf, root, nil)
      vim.notify("ReviewCockpit: artifact missing; guide-only warning opened for " .. range, vim.log.levels.WARN)
    end
  end)
end

return M
