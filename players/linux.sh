#!/usr/bin/env bash
# Play a wav through PipeWire. Usage: player.sh /path/to/file.wav <volume 0..1>
pw-play --volume="$2" "$1" >/dev/null 2>&1
exit 0
