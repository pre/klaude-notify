#!/usr/bin/env bash
# Self-check for sound.sh state logic and the play.sh mute gate.
set -u
cd "$(dirname "$0")"

mutefile=/tmp/claude-mute
volfile=/tmp/claude-volume
saved=$(mktemp -d)
[ -f "$mutefile" ] && cp "$mutefile" "$saved/mute"
[ -f "$volfile" ] && cp "$volfile" "$saved/vol"
restore() {
  rm -f "$mutefile" "$volfile"
  [ -f "$saved/mute" ] && cp "$saved/mute" "$mutefile"
  [ -f "$saved/vol" ] && cp "$saved/vol" "$volfile"
  rm -rf "$saved"
}
trap restore EXIT

fail=0
check() { # check <label> <expected substring> <actual>
  case "$3" in
    *"$2"*) ;;
    *) echo "FAIL $1: expected '*$2*', got '$3'"; fail=1 ;;
  esac
}

rm -f "$mutefile" "$volfile"

check "default state" "sounds on, volume 0.1" "$(./sound.sh status)"
check "toggle on->off" "muted (until unmuted)" "$(./sound.sh)"
check "toggle off->on" "sounds on" "$(./sound.sh)"
check "explicit off" "muted" "$(./sound.sh off)"
check "explicit on" "sounds on" "$(./sound.sh on)"

CLAUDE_SOUND_NOW=1000000000 ./sound.sh 45 >/dev/null
check "timed mute stored" "1000002700" "$(cat $mutefile)"
check "timed mute active" "muted until" "$(CLAUDE_SOUND_NOW=1000002699 ./sound.sh status)"
check "timed mute expired" "sounds on" "$(CLAUDE_SOUND_NOW=1000002701 ./sound.sh status)"
[ -f "$mutefile" ] && { echo "FAIL: expired mute file not removed"; fail=1; }

check "vol set" "volume 0.1" "$(./sound.sh vol 0.1)"
check "vol rejects >1" "between 0 and 1" "$(./sound.sh vol 1.5 2>&1)"
check "vol rejects junk" "usage" "$(./sound.sh vol loud 2>&1)"
check "bad arg" "usage" "$(./sound.sh bogus 2>&1)"

# play.sh gate
wav="$(cd ../assets && pwd)"/warcraft2_sire.wav
./sound.sh on >/dev/null
check "plays when unmuted" "vol=0.1" "$(CLAUDE_PLAY_DRYRUN=1 ./play.sh $wav)"
./sound.sh off >/dev/null
[ -n "$(CLAUDE_PLAY_DRYRUN=1 ./play.sh $wav)" ] && { echo "FAIL: played while muted"; fail=1; }
echo 1000000000 >"$mutefile"
[ -z "$(CLAUDE_PLAY_DRYRUN=1 ./play.sh $wav)" ] && { echo "FAIL: expired mute blocked playback"; fail=1; }
[ -f "$mutefile" ] && { echo "FAIL: play.sh kept expired mute file"; fail=1; }
./sound.sh on >/dev/null
[ -n "$(CLAUDE_PLAY_DRYRUN=1 ./play.sh /nope.wav)" ] && { echo "FAIL: missing wav should be a no-op"; fail=1; }

[ "$fail" = 0 ] && echo "all sound tests passed"
exit "$fail"
