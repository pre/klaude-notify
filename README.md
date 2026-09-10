# klaude-notify

Plays a sound when Claude Code finishes a task or waits for you. The
repository contains the hook scripts, the sounds and an installer that adds
the hooks to any Claude Code profile.

The sound goes through Windows PowerShell, so the hooks work in WSL.

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

The `PreToolUse`, `PostToolUse` and `UserPromptSubmit` hooks count the tools
that run. They keep the hooks silent while Claude waits for its own command.

## Control the sound

```sh
~/.claude/hooks/sound.sh            # mute or unmute
~/.claude/hooks/sound.sh off        # mute
~/.claude/hooks/sound.sh on         # unmute
~/.claude/hooks/sound.sh 45         # mute for 45 minutes
~/.claude/hooks/sound.sh vol 0.15   # volume between 0 and 1
~/.claude/hooks/sound.sh status     # show the state
```

Run `hooks/test-sound.sh` to check the mute and volume logic.
