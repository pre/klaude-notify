#!/usr/bin/env bash
# Play a wav through PipeWire. Usage: player.sh /path/to/file.wav <volume 0..1>

# A suspended sink drops the start of a sound while it wakes up. Bluetooth
# headphones need about 0.5 s. A silent copy of the sound wakes the sink first.
pw-play --volume=0 "$1" >/dev/null 2>&1 &
sleep "${CLAUDE_SOUND_WAKE:-0.8}"
pw-play --volume="$2" "$1" >/dev/null 2>&1
exit 0
