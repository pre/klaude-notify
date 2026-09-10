#!/usr/bin/env bash
# Control Claude notification sounds.
#   sound.sh            toggle mute
#   sound.sh off|on     mute / unmute
#   sound.sh 45         mute for 45 minutes
#   sound.sh vol 0.15   set volume (0..1)
#   sound.sh status     show state
set -u

mutefile=/tmp/claude-mute
volfile=/tmp/claude-volume
default_vol=0.1

now() { echo "${CLAUDE_SOUND_NOW:-$(date +%s)}"; }

# Prints the mute deadline (0 = no deadline) and returns 0 when muted.
# Clears an expired mute file as a side effect.
muted_until() {
  [ -f "$mutefile" ] || return 1
  local u
  u=$(cat "$mutefile" 2>/dev/null)
  case "$u" in
    '' | *[!0-9]*) echo 0; return 0 ;;
  esac
  if [ "$u" -le "$(now)" ]; then
    rm -f "$mutefile"
    return 1
  fi
  echo "$u"
}

volume() {
  local v
  v=$(cat "$volfile" 2>/dev/null)
  case "$v" in
    '' | *[!0-9.]*) v=$default_vol ;;
  esac
  echo "$v"
}

status() {
  local u
  if u=$(muted_until); then
    if [ "$u" = 0 ]; then
      echo "muted (until unmuted), volume $(volume)"
    else
      echo "muted until $(date -d "@$u" '+%H:%M'), volume $(volume)"
    fi
  else
    echo "sounds on, volume $(volume)"
  fi
}

case "${1-}" in
  '')
    if muted_until >/dev/null; then rm -f "$mutefile"; else : >"$mutefile"; fi
    ;;
  off)
    : >"$mutefile"
    ;;
  on)
    rm -f "$mutefile"
    ;;
  vol)
    case "${2-}" in
      '' | *[!0-9.]*) echo "usage: sound.sh vol <0..1>" >&2; exit 1 ;;
    esac
    awk -v v="$2" 'BEGIN { exit !(v >= 0 && v <= 1) }' || {
      echo "volume must be between 0 and 1" >&2
      exit 1
    }
    echo "$2" >"$volfile"
    ;;
  status)
    ;;
  *[!0-9]* )
    echo "usage: sound.sh [off|on|<minutes>|vol <0..1>|status]" >&2
    exit 1
    ;;
  *)
    echo $(( $(now) + $1 * 60 )) >"$mutefile"
    ;;
esac

status
