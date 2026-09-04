# Sourced by install.sh and uninstall.sh: byte-preserving edit of `[ui].theme` in grok's config.toml.

# set_ui_theme FILE VALUE   — write `theme = "VALUE"` into [ui] (created if missing)
# set_ui_theme FILE ""      — remove the `theme = ...` line from [ui]
set_ui_theme() {
  local cfg="$1" value="$2" tmp line=""
  [[ -n $value ]] && line="theme = \"$value\""
  [[ -f $cfg ]] || : >"$cfg"
  tmp=$(mktemp "$cfg.XXXXXX")
  awk -v line="$line" '
    function emit() { if (line != "" && !done) print line; done = 1 }
    function flush() { while (nblank > 0) { print ""; nblank-- } }
    /^\[/ {
      if (in_ui) emit()
      flush()
      in_ui = ($0 ~ /^\[ui\][[:space:]]*(#.*)?$/)
      print; next
    }
    in_ui && /^[[:space:]]*$/ { nblank++; next }
    in_ui && /^[[:space:]]*theme[[:space:]]*=/ { flush(); emit(); next }
    { flush(); print }
    END {
      if (!done && line != "") {
        if (!in_ui) { if (NR > 0) print ""; print "[ui]" }
        print line
      }
      flush()
    }
  ' "$cfg" >"$tmp" && mv "$tmp" "$cfg"
}

# ui_theme_of FILE — print the current [ui].theme value (unquoted), or nothing
ui_theme_of() {
  awk '
    /^\[/ { in_ui = ($0 ~ /^\[ui\][[:space:]]*(#.*)?$/); next }
    in_ui && /^[[:space:]]*theme[[:space:]]*=/ {
      sub(/^[[:space:]]*theme[[:space:]]*=[[:space:]]*/, ""); sub(/[[:space:]]*(#.*)?$/, "")
      gsub(/^"|"$/, ""); print; exit
    }
  ' "$1" 2>/dev/null
}
