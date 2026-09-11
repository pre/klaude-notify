# Shared helpers for the hook scripts. Source after reading stdin into $input.

# Print the string value of a top level field, empty when absent.
hook_field() {
  printf '%s' "$input" | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | head -1 | sed 's/.*"\([^"]*\)"$/\1/'
}

# True when the hook fires inside a subagent. Subagents share the parent's
# session_id, so agent_id is the only marker.
in_subagent() {
  [ -n "$(hook_field agent_id)" ]
}

# True when the Stop input lists a background task that is still running.
# The main agent stops to wait for it and is re-invoked when it ends.
background_running() {
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -e '(.background_tasks // []) | any(.status == "running")' >/dev/null 2>&1
  else
    printf '%s' "$input" | grep -o '"background_tasks"[[:space:]]*:[[:space:]]*\[[^]]*\]' | grep -q '"status"[[:space:]]*:[[:space:]]*"running"'
  fi
}
