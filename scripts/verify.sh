#!/usr/bin/env bash
# Live-retint check for bin/grok-omarchy that never touches the desktop theme.
#
# Runs the pager on a pty with an isolated GROK_HOME and a scratch copy of
# Omarchy's state directory, then swaps `current/theme` exactly the way
# omarchy-theme-set does (render into next-theme, rm -rf theme, mv). The pager
# repaints the cursor with OSC 12 whenever it applies a palette, so the two
# accent_user colors seen on the pty prove the startup palette and the retint.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${1:-$ROOT/bin/grok-omarchy}"
[[ -x $BIN ]] || { echo "error: $BIN missing (scripts/build.sh && scripts/install-bin.sh)" >&2; exit 1; }

exec python3 - "$BIN" <<'PY'
import os, pty, re, select, shutil, signal, sys, tempfile, time, fcntl, termios, struct

binary = sys.argv[1]
tmp = tempfile.mkdtemp(prefix="grok-omarchy-verify.")
home = os.path.join(tmp, "grok-home")
state = os.path.join(tmp, "state")
os.makedirs(home)
os.makedirs(os.path.join(state, "theme"))
with open(os.path.join(home, "config.toml"), "w") as f:
    f.write('[ui]\ntheme = "omarchy"\n')

def render(dirname, base, accent):
    d = os.path.join(state, dirname)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, "grok.toml"), "w") as f:
        f.write(f'base = "{base}"\n[colors]\naccent_user = "{accent}"\nbg_base = "#101010"\n')

render("theme", "dark", "#123456")

env = dict(os.environ,
           GROK_HOME=home, GROK_OMARCHY_STATE_DIR=state,
           GROK_DISABLE_AUTOUPDATER="1", TERM="xterm-256color", COLORTERM="truecolor")
pid, fd = pty.fork()
if pid == 0:
    os.execve(binary, [binary, "--no-auto-update"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))

OSC12 = re.compile(rb"\x1b\]12;rgb:([0-9a-f]{2})/([0-9a-f]{2})/([0-9a-f]{2})")
buf = b""
chunks = []         # (end offset in buf, time read); a sequence may straddle two reads
def pump(until):
    global buf
    while time.time() < until:
        r, _, _ = select.select([fd], [], [], 0.05)
        if not r:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError:
            return
        if not chunk:
            return
        buf += chunk
        chunks.append((len(buf), time.time()))

def seen_at(pos):
    return next(t for end, t in chunks if pos < end)

pump(time.time() + 4.0)
startup = [b"".join(m.groups()).decode() for m in OSC12.finditer(buf)]

# Swap like omarchy-theme-set: next-theme rendered, old dir removed, new one moved in.
render("next-theme", "dark", "#ff0000")
shutil.rmtree(os.path.join(state, "theme"))
t_swap = time.time()
os.rename(os.path.join(state, "next-theme"), os.path.join(state, "theme"))
pump(time.time() + 3.0)

os.kill(pid, signal.SIGTERM)
pump(time.time() + 1.0)
try:
    os.kill(pid, signal.SIGKILL)
except ProcessLookupError:
    pass
os.waitpid(pid, 0)
shutil.rmtree(tmp, ignore_errors=True)

seen = [(seen_at(m.start()), b"".join(m.groups()).decode()) for m in OSC12.finditer(buf)]
print("OSC 12 cursor colors seen:", [c for _, c in seen])
ok = True
if "123456" not in startup:
    print("FAIL: startup palette (accent_user #123456) never applied"); ok = False
retint = [(t, c) for t, c in seen if c == "ff0000" and t >= t_swap]
if retint:
    print(f"PASS: retint to #ff0000 {1000 * (retint[0][0] - t_swap):.0f} ms after the directory swap")
else:
    print("FAIL: no retint to #ff0000 after the directory swap"); ok = False
sys.exit(0 if ok else 1)
PY
