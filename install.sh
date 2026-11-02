#!/usr/bin/env bash
# Install the Claude Code notification sound hooks.
# Usage: ./install.sh [path/settings.json]
# Default: $CLAUDE_CONFIG_DIR/settings.json, or ~/.claude/settings.json
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
target="${1:-$config_dir/settings.json}"

if ! jq empty "$src_dir/hooks.json" 2>/dev/null; then
  echo "Error: $src_dir/hooks.json is not valid JSON" >&2
  jq empty "$src_dir/hooks.json" 2>&1 | sed 's/^/  /' >&2 || true
  exit 1
fi

fragment=$(sed "s|__CLAUDE_DIR__|$config_dir|g" "$src_dir/hooks.json")
if ! printf '%s' "$fragment" | jq -e '.hooks | type == "object" and length > 0' >/dev/null; then
  echo "Error: hooks.json must contain a non-empty .hooks object" >&2
  exit 1
fi

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  platform=wsl
else
  platform=linux
  command -v pw-play >/dev/null || echo "Warning: pw-play not found, the hooks stay silent" >&2
fi

mkdir -p "$config_dir/hooks" "$config_dir/assets" "$(dirname "$target")"
cp "$src_dir"/hooks/*.sh "$config_dir/hooks/"
cp "$src_dir/players/$platform.sh" "$config_dir/hooks/player.sh"
chmod +x "$config_dir"/hooks/*.sh
cp "$src_dir"/assets/*.wav "$config_dir/assets/"

[ -f "$target" ] || echo '{}' > "$target"
if ! jq empty "$target" 2>/dev/null; then
  echo "Error: $target is not valid JSON, refusing to change it" >&2
  exit 1
fi

cp "$target" "$target.bak"
printf '%s' "$fragment" | jq -s '.[0] * .[1]' "$target" - > "$target.tmp"
mv "$target.tmp" "$target"

echo "Installed $platform hooks and sounds to $config_dir, settings: $target (backup: $target.bak)"
