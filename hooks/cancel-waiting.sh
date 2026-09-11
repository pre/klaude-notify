#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)
. "$HERE/hooklib.sh"

# Subagents share the session, so their tool use must not touch its state.
in_subagent && exit 0

session_id=$(hook_field session_id)
[ -z "$session_id" ] && session_id="default"

event=$(hook_field hook_event_name)

pidfile="/tmp/claude-notify-${session_id}.pid"
stopfile="/tmp/claude-stopped-${session_id}"
# Directory of token files acts as an atomic counter of in-flight tools.
# Supports multiple tools running in parallel within one session: a tool is
# "running" while any token exists. Each session has its own dir, so parallel
# Claude CLI instances stay isolated via session_id.
rundir="/tmp/claude-running-${session_id}"
taskturn="/tmp/claude-taskturn-${session_id}"
stoppid="/tmp/claude-stop-${session_id}.pid"

if [ -f "$pidfile" ]; then
  old_pid=$(cat "$pidfile" 2>/dev/null)
  [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
  rm -f "$pidfile"
fi

cancel_stop_sound() {
  [ -f "$stoppid" ] || return 0
  old_pid=$(cat "$stoppid" 2>/dev/null)
  [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
  rm -f "$stoppid"
}

case "$event" in
  Stop)
    touch "$stopfile"
    rm -rf "$rundir"
    ;;
  UserPromptSubmit)
    cancel_stop_sound
    rm -f "$stopfile"
    rm -rf "$rundir"
    # A background task notification arrives as a prompt. Mark the turn so
    # notify-stop.sh delays the sound in case more notifications follow.
    if printf '%s' "$input" | grep -q '<task-notification>'; then
      touch "$taskturn"
    else
      rm -f "$taskturn"
    fi
    ;;
  PreToolUse)
    cancel_stop_sound
    rm -f "$stopfile"
    mkdir -p "$rundir"
    # mktemp guarantees a unique token, so concurrent PreToolUse calls never collide.
    mktemp "$rundir/tok.XXXXXX" >/dev/null 2>&1
    ;;
  PostToolUse)
    if [ -d "$rundir" ]; then
      # Remove exactly one token. `mv` to a unique name first so two concurrent
      # PostToolUse calls can't both claim the same token.
      for tok in "$rundir"/tok.*; do
        [ -e "$tok" ] || continue
        claim="${tok}.claim.$$"
        if mv "$tok" "$claim" 2>/dev/null; then
          rm -f "$claim"
          break
        fi
      done
      rmdir "$rundir" 2>/dev/null || true
    fi
    ;;
esac

exit 0
