#!/usr/bin/env bash
set -euo pipefail

SESSION="Potato"
SHELL_CMD="$(command -v zsh)"
PANE_BORDER_FORMAT='#[fg=#89b4fa,bg=#1e1e2e]#[fg=#11111b,bg=#89b4fa,bold] #{?#{@static_name},#{@static_name},#{pane_title}} #[fg=#89b4fa,bg=#1e1e2e]'
SESSION_TARGET="=${SESSION}"
AGENT_NAMES=(Cora Owen Dave Eric)
AGENT_DIRS=("$HOME/cora" "$HOME/owen" "$HOME/dave" "$HOME/eric")
WATCHDOG_SCRIPT="$HOME/.local/bin/pr-worktree-watchdog"
WATCHDOG_WINDOW="watchdog"
# Older versions used a lowercase session name. Keep this target exact and
# canonical so `work` does not reopen a stale legacy session after prefix+q.

# keep pane names stable
set_static_pane_name() {
  local pane="$1"
  local name="$2"

  tmux select-pane -t "$pane" -T "$name"
  tmux set-option -p -t "$pane" @static_name "$name"
}

# label work panes
apply_work_pane_names() {
  local target="$1"
  local i=0
  local pane=""

  # name agent panes
  while IFS= read -r pane; do
    # stop after agents
    if (( i >= ${#AGENT_NAMES[@]} )); then
      break
    fi
    set_static_pane_name "$pane" "${AGENT_NAMES[$i]}"
    ((i += 1))
  done < <(tmux list-panes -t "$target:Potato" -F "#{pane_id}" 2>/dev/null || true)

  pane="$(tmux list-panes -t "$target:Scratch" -F "#{pane_id}" 2>/dev/null | head -n 1 || true)"
  # name scratch pane
  if [[ -n "$pane" ]]; then
    set_static_pane_name "$pane" "Scratch"
  fi
}

# style all panes
apply_work_pane_format() {
  local target="$1"
  local window=""

  # visit windows
  while IFS= read -r window; do
    tmux set-window-option -t "$window" pane-border-format "$PANE_BORDER_FORMAT"
  done < <(tmux list-windows -t "$target" -F "#{window_id}" 2>/dev/null || true)
}

# detect shell panes
is_shell_pane() {
  local pane_command="$1"

  [[ "$pane_command" == "zsh" || "$pane_command" == "bash" || "$pane_command" == "sh" ]]
}

# wait for shell panes
wait_for_shell_pane() {
  local pane="$1"
  local attempts=0
  local pane_command=""

  # poll shell startup
  while (( attempts < 20 )); do
    pane_command="$(tmux display-message -p -t "$pane" "#{pane_current_command}" 2>/dev/null || true)"
    # stop on shell
    if is_shell_pane "$pane_command"; then
      return 0
    fi
    sleep 0.1
    ((attempts += 1))
  done

  return 1
}

# start or resume one agent
bootstrap_work_agent_pane() {
  local pane="$1"
  local dir_index="$2"
  local force_shell="${3:-0}"
  local pane_command=""

  # wait on new panes
  if [[ "$force_shell" == "1" ]]; then
    wait_for_shell_pane "$pane" || true
  fi

  pane_command="$(tmux display-message -p -t "$pane" "#{pane_current_command}" 2>/dev/null || true)"
  # skip active processes
  if [[ "$force_shell" != "1" ]] && ! is_shell_pane "$pane_command"; then
    return
  fi

  tmux send-keys -t "$pane" "cd ${AGENT_DIRS[$dir_index]@Q} && if git symbolic-ref -q HEAD >/dev/null 2>&1; then resume; else :; fi" C-m
}

# start or resume agent panes
bootstrap_work_agent_panes() {
  local target="$1"
  local i=0
  local pane=""

  # visit agent panes
  while IFS= read -r pane; do
    # stop after agents
    if (( i >= ${#AGENT_DIRS[@]} )); then
      break
    fi

    bootstrap_work_agent_pane "$pane" "$i"
    ((i += 1))
  done < <(tmux list-panes -t "$target:Potato" -F "#{pane_id}" 2>/dev/null || true)
}

# start watchdog pane
bootstrap_watchdog_pane() {
  local pane="$1"
  local pane_command=""

  wait_for_shell_pane "$pane" || true
  pane_command="$(tmux display-message -p -t "$pane" "#{pane_current_command}" 2>/dev/null || true)"
  # skip active watchdog
  if ! is_shell_pane "$pane_command"; then
    return
  fi

  tmux send-keys -t "$pane" "cd ${HOME@Q} && exec ${WATCHDOG_SCRIPT@Q} --loop --verbose" C-m
}

# ensure watchdog window
ensure_watchdog_window() {
  local target="$1"
  local pane=""
  local window_id=""

  # find existing window
  while IFS=$'\t' read -r window_id window_name; do
    # match exact name
    if [[ "$window_name" == "$WATCHDOG_WINDOW" ]]; then
      pane="$(tmux list-panes -t "$window_id" -F "#{pane_id}" 2>/dev/null | head -n 1 || true)"
      break
    fi
  done < <(tmux list-windows -t "$target" -F "#{window_id}\t#{window_name}" 2>/dev/null || true)

  # create missing window
  if [[ -z "$pane" ]]; then
    pane="$(tmux new-window -d -t "$target" -n "$WATCHDOG_WINDOW" -P -F "#{pane_id}" "$SHELL_CMD")"
  fi

  # start when idle
  if [[ -n "$pane" ]]; then
    set_static_pane_name "$pane" "watchdog"
    bootstrap_watchdog_pane "$pane"
  fi
}

# reuse existing session
if tmux has-session -t "$SESSION_TARGET" 2>/dev/null; then
  ensure_watchdog_window "$SESSION_TARGET"
  apply_work_pane_format "$SESSION_TARGET"
  apply_work_pane_names "$SESSION_TARGET"
  bootstrap_work_agent_panes "$SESSION_TARGET"
  exec tmux attach-session -t "$SESSION_TARGET"
fi

tmux new-session -d -s "$SESSION" -n "Potato" "$SHELL_CMD"
zero_pane="$(tmux list-panes -t "$SESSION_TARGET:Potato" -F "#{pane_id}" | head -n 1)"
one_pane="$(tmux split-window -h -t "$SESSION_TARGET:Potato" -P -F "#{pane_id}" "$SHELL_CMD")"
two_pane="$(tmux split-window -h -t "$SESSION_TARGET:Potato" -P -F "#{pane_id}" "$SHELL_CMD")"
three_pane="$(tmux split-window -h -t "$SESSION_TARGET:Potato" -P -F "#{pane_id}" "$SHELL_CMD")"

tmux select-layout -t "$SESSION_TARGET:Potato" even-horizontal

set_static_pane_name "$zero_pane" "Cora"
set_static_pane_name "$one_pane" "Owen"
set_static_pane_name "$two_pane" "Dave"
set_static_pane_name "$three_pane" "Eric"

bootstrap_work_agent_pane "$zero_pane" 0 1
bootstrap_work_agent_pane "$one_pane" 1 1
bootstrap_work_agent_pane "$two_pane" 2 1
bootstrap_work_agent_pane "$three_pane" 3 1

scratch_pane="$(tmux new-window -d -t "$SESSION_TARGET" -n "Scratch" -P -F "#{pane_id}" "$SHELL_CMD")"
set_static_pane_name "$scratch_pane" "Scratch"
tmux send-keys -t "$scratch_pane" "cd ${AGENT_DIRS[0]@Q}" C-m

ensure_watchdog_window "$SESSION_TARGET"
apply_work_pane_format "$SESSION_TARGET"
tmux select-window -t "$SESSION_TARGET:Potato"
exec tmux attach-session -t "$SESSION_TARGET"
