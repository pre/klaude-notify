#!/usr/bin/env bash
set -u

input=$(cat)
session_id=$(printf '%s' "$input" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
[ -z "$session_id" ] && session_id="default"

event=$(printf '%s' "$input" | grep -o '"hook_event_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

pidfile="/tmp/claude-notify-${session_id}.pid"
stopfile="/tmp/claude-stopped-${session_id}"
# Directory of token files acts as an atomic counter of in-flight tools.
# Supports multiple tools running in parallel within one session: a tool is
# "running" while any token exists. Each session has its own dir, so parallel
# Claude CLI instances stay isolated via session_id.
rundir="/tmp/claude-running-${session_id}"

if [ -f "$pidfile" ]; then
  old_pid=$(cat "$pidfile" 2>/dev/null)
  [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
  rm -f "$pidfile"
fi

case "$event" in
  Stop)
    touch "$stopfile"
    rm -rf "$rundir"
    ;;
  UserPromptSubmit)
    rm -f "$stopfile"
    rm -rf "$rundir"
    ;;
  PreToolUse)
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
