#!/usr/bin/env bash
# Play a wav through Windows from WSL. Usage: player.sh /path/to/file.wav <volume 0..1>
set -u
win=$(wslpath -w "$1")

powershell.exe -NoProfile -Command "
Add-Type -AssemblyName presentationCore
\$p = New-Object System.Windows.Media.MediaPlayer
\$p.Open([uri]'$win')
\$p.Volume = $2
for (\$i = 0; \$i -lt 20 -and -not \$p.NaturalDuration.HasTimeSpan; \$i++) { Start-Sleep -Milliseconds 50 }
\$p.Play()
\$d = 5
if (\$p.NaturalDuration.HasTimeSpan) { \$d = \$p.NaturalDuration.TimeSpan.TotalSeconds + 0.3 }
Start-Sleep -Seconds \$d
" >/dev/null 2>&1

exit 0
