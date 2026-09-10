#!/usr/bin/env bash
# Play a wav through Windows from WSL. Usage: play.sh /path/to/file.wav
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

win=$(wslpath -w "$1")

[ -n "${CLAUDE_PLAY_DRYRUN-}" ] && { echo "play $win vol=$vol"; exit 0; }

powershell.exe -NoProfile -Command "
Add-Type -AssemblyName presentationCore
\$p = New-Object System.Windows.Media.MediaPlayer
\$p.Open([uri]'$win')
\$p.Volume = $vol
for (\$i = 0; \$i -lt 20 -and -not \$p.NaturalDuration.HasTimeSpan; \$i++) { Start-Sleep -Milliseconds 50 }
\$p.Play()
\$d = 5
if (\$p.NaturalDuration.HasTimeSpan) { \$d = \$p.NaturalDuration.TimeSpan.TotalSeconds + 0.3 }
Start-Sleep -Seconds \$d
" >/dev/null 2>&1

exit 0
