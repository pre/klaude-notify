#!/usr/bin/env bash
# Play a wav with the platform player. Usage: play.sh /path/to/file.wav
# Silent while /tmp/claude-mute exists; volume from /tmp/claude-volume. See sound.sh.
set -u
[ -f "$1" ] || exit 0

mutefile=/tmp/claude-mute
if [ -f "$mutefile" ]; then
  until=$(cat "$mutefile" 2>/dev/null)
  case "$until" in
    '' | *[!0-9]*) exit 0 ;;
  esac
  [ "$until" -gt "$(date +%s)" ] && exit 0
  rm -f "$mutefile"
fi

vol=$(cat /tmp/claude-volume 2>/dev/null)
case "$vol" in
  '' | *[!0-9.]*) vol=0.1 ;;
esac

[ -n "${CLAUDE_PLAY_DRYRUN-}" ] && { echo "play $1 vol=$vol"; exit 0; }

# install.sh copies the WSL or the Linux player here.
exec "$(dirname "$0")/player.sh" "$1" "$vol"
