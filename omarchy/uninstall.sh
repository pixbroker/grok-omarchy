#!/bin/bash
# Remove the template and put `[ui].theme` back to what it was before install.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
CONFIG="$GROK_HOME/config.toml"
BACKUP="$GROK_HOME/config.toml.pre-omarchy"
source "$ROOT/lib/grok-config.sh"

rm -f "$HOME/.config/omarchy/themed/grok.toml.tpl"
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/grok-theme"
[[ -L $GROK_HOME/themes/omarchy.toml ]] && rm -f "$GROK_HOME/themes/omarchy.toml"
rmdir "$GROK_HOME/themes" 2>/dev/null || true

if [[ -f $CONFIG ]]; then
  previous=""
  [[ -f $BACKUP ]] && previous=$(ui_theme_of "$BACKUP")
  set_ui_theme "$CONFIG" "$previous"
  echo "config:   $CONFIG ([ui] theme = \"${previous:-<unset>}\")"
fi

omarchy-theme-refresh
echo "removed:  $HOME/.config/omarchy/themed/grok.toml.tpl"
