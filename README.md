# klaude-notify

Plays a sound when Claude Code finishes a task or waits for you. The
repository contains the hook scripts, the sounds and an installer that adds
the hooks to any Claude Code profile.

The hooks work in WSL and in Linux. The installer finds the platform and
installs one of two players as `hooks/player.sh`:

| Platform | Player | Plays the sound with |
| --- | --- | --- |
| WSL | `players/wsl.sh` | Windows PowerShell |
| Linux | `players/linux.sh` | `pw-play` (PipeWire) |

The installer finds WSL when `/proc/sys/kernel/osrelease` contains
`microsoft`. On other machines it installs the Linux player. If `pw-play` is
not available, the installer shows a warning and the hooks do not play a
sound.

PipeWire suspends an idle sink. A suspended sink drops the start of a sound
while it wakes up, and Bluetooth headphones need about 0.5 seconds. The Linux
player first plays a silent copy of the sound to wake the sink. It starts the
sound 0.8 seconds later. Set `CLAUDE_SOUND_WAKE` to change this delay in
seconds.

## Installation

The installer needs `jq`. Run `./install.sh`. The script copies the scripts
to `hooks/` and the sounds to `assets/` in the profile directory, then merges
`hooks.json` into the `settings.json` file and makes a backup with the `.bak`
suffix. The target is `$CLAUDE_CONFIG_DIR/settings.json` when the variable is
set, otherwise `~/.claude/settings.json`. A path given as an argument
overrides both.

```sh
./install.sh                                    # ~/.claude
CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh   # another profile
./install.sh /path/settings.json                # any other target
```

The script checks that `hooks.json` and the target file are valid JSON before
it changes the target. The merge replaces the `Notification`, `PreToolUse`,
`PostToolUse`, `UserPromptSubmit` and `Stop` hook lists. Use the backup file
when you have your own hooks for these events.

## Sounds

| Event | Sound |
| --- | --- |
| Claude completes the answer (`Stop`) | `warcraft2_wahoo.wav` |
| Claude waits for you (`Notification`) | `warcraft2_awaiting_orders.wav` |
| Claude waits for you 60 seconds more | `warcraft2_sire.wav` |

The sounds are from the game Warcraft II. Blizzard Entertainment owns the
copyright of the sound files, and the MIT License of this repository does not
apply to them. To use other sounds, put your own wav files with the same names
in `assets/` before you run `./install.sh`.

The `PreToolUse`, `PostToolUse` and `UserPromptSubmit` hooks count the tools
that run. They keep the hooks silent while Claude waits for its own command.

## Main agent only

The hooks play a sound for the main agent only. Subagents (the `Agent` tool)
share the `session_id` of the main agent, but their hook input has the
`agent_id` and `agent_type` fields. Each hook script stops at once when it
finds `agent_id`, so a subagent does not play a sound and does not change the
tool counter of the session.

The main agent stops each time it waits for a background subagent or a
background command. The Stop hook input lists these in `background_tasks`.
The `notify-stop.sh` script stays silent while a task in that list has the
status `running`, and plays the sound only when the main agent has no
background work left. A background command that never ends, for example a
development server, keeps the Stop sound silent until it ends.

A finished background task comes back to the main agent as a task
notification prompt. When two tasks finish at the same time, the second
notification arrives directly after the main agent stops. In a turn that a
task notification started, `notify-stop.sh` waits 3 seconds before it plays
the sound, and the next notification or tool use cancels it. Set
`CLAUDE_STOP_GRACE` to change the wait in seconds.

## Control the sound

```sh
~/.claude/hooks/sound.sh            # mute or unmute
~/.claude/hooks/sound.sh off        # mute
~/.claude/hooks/sound.sh on         # unmute
~/.claude/hooks/sound.sh 45         # mute for 45 minutes
~/.claude/hooks/sound.sh vol 0.15   # volume between 0 and 1
~/.claude/hooks/sound.sh status     # show the state
```

Run `hooks/test-sound.sh` to check the mute and volume logic and
`hooks/test-hooks.sh` to check the main agent and subagent logic.
