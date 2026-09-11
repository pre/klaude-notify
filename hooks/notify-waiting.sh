#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"

input=$(cat)
. "$HERE/hooklib.sh"

in_subagent && exit 0

session_id=$(hook_field session_id)
[ -z "$session_id" ] && session_id="default"

notification_type=$(hook_field notification_type)

pidfile="/tmp/claude-notify-${session_id}.pid"
stopfile="/tmp/claude-stopped-${session_id}"
rundir="/tmp/claude-running-${session_id}"

# A tool is in flight if the run dir exists and holds at least one token.
tool_running() {
  [ -d "$rundir" ] || return 1
  for tok in "$rundir"/tok.*; do
    [ -e "$tok" ] && return 0
  done
  return 1
}

if [ -f "$stopfile" ]; then
  exit 0
fi

# An idle_prompt fired while a tool is still running means Claude is waiting on
# its own command (e.g. a long `sleep`), not on the user. Stay silent.
if [ "$notification_type" = "idle_prompt" ] && tool_running; then
  exit 0
fi

if [ -f "$pidfile" ]; then
  old_pid=$(cat "$pidfile" 2>/dev/null)
  [ -n "$old_pid" ] && kill "$old_pid" 2>/dev/null
  rm -f "$pidfile"
fi

speak() {
  "$HERE/play.sh" "$1"
}

speak "$HERE/../assets/warcraft2_awaiting_orders.wav" &

(
  sleep 60
  [ -f "/tmp/claude-stopped-${session_id}" ] && exit 0
  tool_running && exit 0
  speak "$HERE/../assets/warcraft2_sire.wav"
  rm -f "$pidfile"
) &
echo $! > "$pidfile"
disown 2>/dev/null || true

exit 0
