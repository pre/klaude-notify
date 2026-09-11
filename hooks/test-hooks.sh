#!/usr/bin/env bash
# Self-check for the hook scripts: subagent inputs stay silent, main agent
# inputs work as before. Uses CLAUDE_PLAY_DRYRUN so no sound plays.
set -u
cd "$(dirname "$0")"
export CLAUDE_PLAY_DRYRUN=1

sid="test-hooks-$$"
cleanup() {
  [ -f "/tmp/claude-notify-${sid}.pid" ] && kill "$(cat "/tmp/claude-notify-${sid}.pid")" 2>/dev/null
  [ -f "/tmp/claude-stop-${sid}.pid" ] && kill "$(cat "/tmp/claude-stop-${sid}.pid")" 2>/dev/null
  rm -rf "/tmp/claude-notify-${sid}.pid" "/tmp/claude-stopped-${sid}" "/tmp/claude-running-${sid}" \
    "/tmp/claude-taskturn-${sid}" "/tmp/claude-stop-${sid}.pid"
}
trap cleanup EXIT
cleanup
rm -f /tmp/claude-mute

fail=0
ok() { echo "FAIL $1"; fail=1; }

main() { # main <event> [extra json fields]
  printf '{"session_id":"%s","hook_event_name":"%s"%s}' "$sid" "$1" "${2-}"
}
sub() { # sub <event> [extra json fields]
  main "$1" ",\"agent_id\":\"a1b2c3\",\"agent_type\":\"Explore\"${2-}"
}
running='"background_tasks":[{"id":"a1b2c3","type":"subagent","status":"running"}]'
finished='"background_tasks":[{"id":"a1b2c3","type":"subagent","status":"completed"}]'

# notify-stop.sh
wav="$(cd ../assets && pwd)"/warcraft2_wahoo.wav
out=$(main Stop ",\"background_tasks\":[]" | ./notify-stop.sh "$wav")
case "$out" in *wahoo*) ;; *) ok "main Stop plays wahoo (got '$out')" ;; esac
out=$(main Stop | ./notify-stop.sh "$wav")
case "$out" in *wahoo*) ;; *) ok "main Stop without background_tasks plays wahoo" ;; esac
out=$(main Stop ",$finished" | ./notify-stop.sh "$wav")
case "$out" in *wahoo*) ;; *) ok "main Stop with finished tasks plays wahoo" ;; esac
[ -n "$(main Stop ",$running" | ./notify-stop.sh "$wav")" ] && ok "main Stop with a running background task must be silent"
nojq="/usr/bin:/bin"
if ! PATH="$nojq" command -v jq >/dev/null 2>&1; then
  [ -n "$(main Stop ",$running" | PATH="$nojq" ./notify-stop.sh "$wav")" ] && ok "running task must be silent without jq"
  out=$(main Stop ",$finished" | PATH="$nojq" ./notify-stop.sh "$wav")
  case "$out" in *wahoo*) ;; *) ok "finished tasks play wahoo without jq" ;; esac
fi
[ -n "$(sub Stop | ./notify-stop.sh "$wav")" ] && ok "subagent Stop must be silent"
[ -n "$(sub SubagentStop | ./notify-stop.sh "$wav")" ] && ok "SubagentStop must be silent"

# Delayed Stop sound after a task notification turn
export CLAUDE_STOP_GRACE=1
main UserPromptSubmit ',"prompt":"<task-notification>\n<task-id>a1</task-id>"' | ./cancel-waiting.sh
[ -f "/tmp/claude-taskturn-${sid}" ] || ok "task notification prompt marks the turn"
capture=$(mktemp)
main Stop ',"background_tasks":[]' | ./notify-stop.sh "$wav" >"$capture"
[ -f "/tmp/claude-stop-${sid}.pid" ] || ok "Stop in a task turn schedules a delayed sound"
[ -s "$capture" ] && ok "Stop in a task turn must not play at once"
main UserPromptSubmit ',"prompt":"<task-notification>\n<task-id>a2</task-id>"' | ./cancel-waiting.sh
[ -f "/tmp/claude-stop-${sid}.pid" ] && ok "next task notification cancels the delayed sound"
sleep 2
[ -s "$capture" ] && ok "cancelled delayed sound must stay silent (got '$(cat "$capture")')"
main Stop ',"background_tasks":[]' | ./notify-stop.sh "$wav" >"$capture"
sleep 2
grep -q wahoo "$capture" || ok "delayed sound plays when nothing cancels it"
[ -f "/tmp/claude-stop-${sid}.pid" ] && ok "delayed sound removes its pid file"
main UserPromptSubmit ',"prompt":"hello"' | ./cancel-waiting.sh
[ -f "/tmp/claude-taskturn-${sid}" ] && ok "a user prompt clears the task turn mark"
out=$(main Stop ',"background_tasks":[]' | ./notify-stop.sh "$wav")
case "$out" in *wahoo*) ;; *) ok "Stop in a user turn plays at once" ;; esac
rm -f "$capture"

# cancel-waiting.sh: subagent tool use must not touch the session state
main Stop | ./cancel-waiting.sh
[ -f "/tmp/claude-stopped-${sid}" ] || ok "main Stop creates the stop file"
sub PreToolUse ',"tool_name":"Bash"' | ./cancel-waiting.sh
[ -f "/tmp/claude-stopped-${sid}" ] || ok "subagent PreToolUse must keep the stop file"
[ -d "/tmp/claude-running-${sid}" ] && ok "subagent PreToolUse must not add a running token"
main PreToolUse ',"tool_name":"Bash"' | ./cancel-waiting.sh
[ -f "/tmp/claude-stopped-${sid}" ] && ok "main PreToolUse removes the stop file"
[ -d "/tmp/claude-running-${sid}" ] || ok "main PreToolUse adds a running token"
sub PostToolUse ',"tool_name":"Bash"' | ./cancel-waiting.sh
[ -d "/tmp/claude-running-${sid}" ] || ok "subagent PostToolUse must not remove a running token"
main PostToolUse ',"tool_name":"Bash"' | ./cancel-waiting.sh
[ -d "/tmp/claude-running-${sid}" ] && ok "main PostToolUse removes the running token"

# notify-waiting.sh
capture=$(mktemp)
sub Notification ',"notification_type":"idle_prompt"' | ./notify-waiting.sh >"$capture"
sleep 1
[ -s "$capture" ] && ok "subagent Notification must be silent"
[ -f "/tmp/claude-notify-${sid}.pid" ] && ok "subagent Notification must not start the reminder"
main Notification ',"notification_type":"idle_prompt"' | ./notify-waiting.sh >"$capture"
sleep 1
grep -q awaiting_orders "$capture" || ok "main Notification plays awaiting orders (got '$(cat "$capture")')"
rm -f "$capture"
[ -f "/tmp/claude-notify-${sid}.pid" ] || ok "main Notification starts the reminder"

[ "$fail" = 0 ] && echo "all hook tests passed"
exit "$fail"
