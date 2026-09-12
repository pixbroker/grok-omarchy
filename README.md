# grok-omarchy

A small local patch of [Grok Build](https://github.com/xai-org/grok-build) so the TUI follows the [Omarchy](https://omarchy.org/) desktop theme, live, the way Ghostty does.

## How it works

Omarchy renders every `~/.config/omarchy/themed/*.tpl` on each theme change and swaps the result into `~/.local/state/omarchy/current/theme/` atomically. This repo adds one such template, `grok.toml.tpl`, which maps Omarchy's palette onto Grok's `Theme` fields:

```toml
base = "dark"            # theme_type: picks Grok Night or Grok Day underneath
[colors]
bg_base = "#2e3440"      # any Theme color field, #rrggbb
accent_user = "#81a1c1"
...
```

The patched pager, with `[ui] theme = "omarchy"` in `~/.grok/config.toml`:

- reads `current/theme/grok.toml` at startup and lays its colors over Grok Night or Grok Day;
- holds an inotify watch on `current/`, which survives the directory swap, through the [omarchy-theme](https://crates.io/crates/omarchy-themes) crate;
- on any event re-reads the file and, only if the palette actually changed, retints and repaints the cursor.

That is the same moment Omarchy signals Ghostty, with no hook, no signal, and no polling. Nothing in Omarchy is modified; the template directory is a supported user extension point.

## Patch to grok-build

The Omarchy side of the mechanism (locating the state directory, reading the rendered file, the swap-tolerant watch) is the shared crate [omarchy-themes](https://crates.io/crates/omarchy-themes), so any app can follow the theme the same way. Grok keeps only what is Grok-specific: the slot table and the render-cache stamp.

`patches/` holds the `git format-patch` export of branch `omarchy` against upstream `72a61251`:

| File | Change |
|------|--------|
| `xai-grok-pager-render/src/theme/omarchy.rs` | New. Parses the rendered file into a color-slot overlay and keeps a generation counter; the state directory, file read and inotify watch come from `omarchy-themes`. |
| `xai-grok-pager-render/src/theme/mod.rs` | `Theme::current()` takes the Omarchy palette when present. |
| `xai-grok-pager-render/src/theme/cache.rs` | `theme = "omarchy"` enables the mode; `ThemeStamp` = kind + overlay generation. |
| `xai-grok-pager/src/scrollback/entry.rs`, `blocks/markdown_content.rs` | Render caches key on `ThemeStamp` so a new palette re-bakes old blocks. |
| `xai-grok-pager/src/app/event_loop.rs` | One `select!` arm: watcher fired → reload → `apply_kind` + redraw. |
| `xai-grok-pager-render/Cargo.toml` | Adds [`omarchy-themes`](https://crates.io/crates/omarchy-themes) 0.1 with the `tokio` feature. |
| `xai-grok-pager-bin/src/main.rs`, `xai-grok-update/src/os_repo.rs` | Managed `<grok_home>/bin/grok` still checks the release channel and can adopt a staged download. A source build (this binary) cannot, but it still nags when the first CHANGELOG version on [`xai-org/grok-build`](https://github.com/xai-org/grok-build) main is ahead of the running release (`1.0.16-omarchy.<sha>` counts as `1.0.16`, so it no longer looks stale against a behind-stable pointer). Ctrl+U prints rebase instructions instead of running `grok update`. |

Stock `grok` ignores the unknown name `omarchy` and falls back to Grok Night, so the config is safe for both binaries. `/theme` and `/settings` still list only the built-in themes; while omarchy mode is on they only change the syntax-highlight polarity underneath.

## Install

```bash
~/Work/grok-omarchy/scripts/build.sh         # cargo build -p xai-grok-pager-bin --release
~/Work/grok-omarchy/scripts/install-bin.sh   # -> bin/grok-omarchy
~/Work/grok-omarchy/omarchy/install.sh       # template + [ui] theme = "omarchy" + omarchy-theme-refresh
```

`bin/` is on `PATH`, so run `grok-omarchy`. Stock `~/.grok/bin/grok` is untouched and keeps auto-updating.

## Verify

```bash
~/Work/grok-omarchy/scripts/verify.sh
```

Runs `bin/grok-omarchy` on a pty with an isolated `GROK_HOME` and a scratch Omarchy state directory (`GROK_OMARCHY_STATE_DIR`), swaps `theme/` the way `omarchy-theme-set` does, and reads the OSC 12 cursor-color escapes the pager emits on every palette apply. It prints the retint latency and never touches the desktop theme.

```bash
~/Work/grok-omarchy/scripts/verify-desktop.sh [other-theme]   # default tokyo-night
```

The opt-in end-to-end check: same pty harness, but against the real Omarchy state directory while it runs `omarchy-theme-set` to the other theme and back to the current one. Every app on the desktop retints during those few seconds.

## Uninstall

```bash
~/Work/grok-omarchy/omarchy/uninstall.sh   # removes the template, restores [ui].theme from config.toml.pre-omarchy
rm -f ~/Work/grok-omarchy/bin/grok-omarchy
```

## Rebase

Upstream takes no external PRs, so this stays a local branch. `scripts/rebase.sh` fetches `upstream/main`, rebases `omarchy`, then rebuilds, installs and re-exports `patches/`. Files most likely to conflict: `event_loop.rs`, `cache.rs`, `mod.rs`.

## Limitations

- Fenced-code syntax highlighting keeps Grok's baked night/day tmTheme; only its polarity follows Omarchy.
- Mermaid renders and diff syntax spans are cached per built-in kind, not per palette, so an already-rendered diagram keeps its colors until re-rendered.
- If the inotify watch cannot be created (no Omarchy state dir, watch limit), the palette is read once at startup and a warning is logged; there is no fallback poll.
