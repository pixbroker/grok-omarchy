#!/bin/bash
# Omarchy side of grok-omarchy: the user template Omarchy renders on every theme
# change, and `[ui] theme = "omarchy"` so the patched pager follows it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CONFIG="$GROK_HOME/config.toml"
BACKUP="$GROK_HOME/config.toml.pre-omarchy"
RENDERED="$HOME/.local/state/omarchy/current/theme/grok.toml"
source "$ROOT/lib/grok-config.sh"

mkdir -p "$HOME/.config/omarchy/themed" "$GROK_HOME"
cp "$ROOT/themed/grok.toml.tpl" "$HOME/.config/omarchy/themed/grok.toml.tpl"

# Leftovers from the earlier hook/symlink/poll design.
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/grok-theme" "$ROOT/../bin/omarchy-restart-terminal"
[[ -L $GROK_HOME/themes/omarchy.toml ]] && rm -f "$GROK_HOME/themes/omarchy.toml"
rmdir "$GROK_HOME/themes" 2>/dev/null || true

[[ -f $CONFIG && ! -f $BACKUP ]] && cp "$CONFIG" "$BACKUP"
set_ui_theme "$CONFIG" omarchy

omarchy-theme-refresh

if [[ ! -f $RENDERED ]]; then
  echo "error: Omarchy did not render $RENDERED" >&2
  exit 1
fi
if grep -q '{{' "$RENDERED"; then
  echo "error: unresolved placeholders in $RENDERED:" >&2
  grep -n '{{' "$RENDERED" >&2
  exit 1
fi

echo "template: $HOME/.config/omarchy/themed/grok.toml.tpl"
echo "rendered: $RENDERED ($(grep -m1 '^base' "$RENDERED"))"
echo "config:   $CONFIG ([ui] theme = \"$(ui_theme_of "$CONFIG")\")"
echo "Restart any grok-omarchy session started before this install."
