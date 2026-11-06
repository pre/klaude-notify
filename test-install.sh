#!/usr/bin/env bash
# Self-check for install.sh: hooks of other tools stay, hooks of an earlier
# klaude-notify install are replaced, and a second install changes nothing.
set -u
cd "$(dirname "$0")"

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
settings="$dir/settings.json"

fail=0
ok() { echo "FAIL $1"; fail=1; }
count() { # count <event> <command prefix>
  jq --arg e "$1" --arg c "$2" '[.hooks[$e][].hooks[].command | select(startswith($c))] | length' "$settings"
}

cat >"$settings" <<EOF
{
  "model": "opus",
  "hooks": {
    "SessionStart": [ { "hooks": [ { "type": "command", "command": "other-start.sh" } ] } ],
    "PreToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": "$dir/hooks/cancel-waiting.sh" } ] },
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "other-pre.sh --flag", "timeout": 5 } ] }
    ],
    "Stop": [ { "hooks": [
      { "type": "command", "command": "$dir/hooks/cancel-waiting.sh" },
      { "type": "command", "command": "other-stop.sh" }
    ] } ]
  }
}
EOF

out=$(CLAUDE_CONFIG_DIR="$dir" ./install.sh 2>/dev/null) || ok "install.sh exits non-zero"
first=$(cat "$settings")

[ "$(jq -r .model "$settings")" = opus ] || ok "other settings stay"
[ "$(count SessionStart other-start.sh)" = 1 ] || ok "SessionStart hook of another tool stays"
[ "$(count PreToolUse other-pre.sh)" = 1 ] || ok "PreToolUse hook of another tool stays"
[ "$(jq '.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[0].timeout' "$settings")" = 5 ] ||
  ok "other hook keeps its fields"
[ "$(count Stop other-stop.sh)" = 1 ] || ok "Stop hook of another tool stays in a shared entry"
[ "$(count PreToolUse "$dir/hooks/cancel-waiting.sh")" = 1 ] || ok "earlier PreToolUse hook is replaced, not doubled"
[ "$(count Stop "$dir/hooks/cancel-waiting.sh")" = 1 ] || ok "earlier Stop hook is replaced, not doubled"
[ "$(count Stop "$dir/hooks/notify-stop.sh")" = 1 ] || ok "new Stop hook is added"
[ "$(count Notification "$dir/hooks/notify-waiting.sh")" = 1 ] || ok "new Notification hook is added"

grep -q "PreToolUse: keeps other-pre.sh --flag" <<<"$out" || ok "output names the kept hook"
grep -q "PreToolUse: replaces $dir/hooks/cancel-waiting.sh" <<<"$out" || ok "output names the replaced hook"

CLAUDE_CONFIG_DIR="$dir" ./install.sh >/dev/null 2>&1 || ok "second install.sh exits non-zero"
[ "$(cat "$settings")" = "$first" ] || ok "second install changes nothing"

[ "$fail" = 0 ] && echo "PASS"
exit "$fail"
