#!/usr/bin/env bash
# Opt-in end-to-end check: switches the real desktop theme to OTHER and back to
# the current one while bin/grok-omarchy runs on a pty (isolated GROK_HOME, real
# Omarchy state dir). Prints when the pager retinted relative to the directory
# swap. Every other app on the desktop retints too, so run it when that is fine.
#
#   scripts/verify-desktop.sh [OTHER=tokyo-night]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/bin/grok-omarchy"
OTHER="${1:-tokyo-night}"
BACK="$(cat "$HOME/.local/state/omarchy/current/theme.name")"
[[ -x $BIN ]] || { echo "error: $BIN missing" >&2; exit 1; }
[[ $OTHER != "$BACK" ]] || { echo "error: pick a theme other than the current one ($BACK)" >&2; exit 1; }

exec python3 - "$BIN" "$OTHER" "$BACK" <<'PY'
import os, pty, re, select, signal, subprocess, sys, tempfile, time, fcntl, termios, struct
binary, other, back = sys.argv[1:4]
home = tempfile.mkdtemp(prefix="grok-omarchy-desktop.")
with open(os.path.join(home, "config.toml"), "w") as f:
    f.write('[ui]\ntheme = "omarchy"\n')
env = dict(os.environ, GROK_HOME=home, GROK_DISABLE_AUTOUPDATER="1", TERM="xterm-256color", COLORTERM="truecolor")
env.pop("GROK_OMARCHY_STATE_DIR", None)
pid, fd = pty.fork()
if pid == 0:
    os.execve(binary, [binary, "--no-auto-update"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

OSC12 = re.compile(rb"\x1b\]12;rgb:([0-9a-f]{2})/([0-9a-f]{2})/([0-9a-f]{2})")
buf = b""
chunks = []
def pump(until, proc=None):
    global buf
    while time.time() < until:
        r, _, _ = select.select([fd], [], [], 0.02)
        if r:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                return
            if not chunk:
                return
            buf += chunk
            chunks.append((len(buf), time.time()))
        if proc is not None and proc.poll() is not None:
            proc = None
def colors():
    return [(next(t for end, t in chunks if m.start() < end), b"".join(m.groups()).decode())
            for m in OSC12.finditer(buf)]

name_file = os.path.expanduser("~/.local/state/omarchy/current/theme.name")
pump(time.time() + 4)
print("startup accent:", [c for _, c in colors()])
ok = True
for name in (other, back):
    before = len(colors())
    proc = subprocess.Popen(["omarchy-theme-set", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    pump(time.time() + 3.5, proc)   # keep draining the pty while the switch runs
    proc.wait()
    swap = os.stat(name_file).st_mtime  # written right after the theme dir swap
    after = colors()[before:]
    if after:
        t, c = after[0]
        print(f"-> {name}: retint to #{c} {1000 * (t - swap):+.0f} ms from the theme dir swap")
    else:
        print(f"-> {name}: FAIL, no retint"); ok = False

os.kill(pid, signal.SIGTERM)
pump(time.time() + 1)
try:
    os.kill(pid, signal.SIGKILL)
except ProcessLookupError:
    pass
os.waitpid(pid, 0)
sys.exit(0 if ok else 1)
PY
