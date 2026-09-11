#!/usr/bin/env bash
# Stop hook: play the done sound for the main agent only.
# Usage: notify-stop.sh /path/to/file.wav  (hook input on stdin)
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
input=$(cat)
. "$HERE/hooklib.sh"

in_subagent && exit 0
background_running && exit 0

session_id=$(hook_field session_id)
[ -z "$session_id" ] && session_id="default"
taskturn="/tmp/claude-taskturn-${session_id}"
stoppid="/tmp/claude-stop-${session_id}.pid"

# A turn that a task notification started can be followed at once by the next
# notification. Wait a moment so cancel-waiting.sh can cancel the sound.
if [ -f "$taskturn" ]; then
  (
    sleep "${CLAUDE_STOP_GRACE:-3}"
    rm -f "$stoppid"
    "$HERE/play.sh" "$1"
  ) &
  echo $! > "$stoppid"
  disown 2>/dev/null || true
  exit 0
fi

"$HERE/play.sh" "$1"
exit 0
