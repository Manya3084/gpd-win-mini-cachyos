#!/usr/bin/bash
# Make Steam treat Guide/Menu + right bumper as "Take Screenshot" in the gamepad UI, so the
# L4 back button (which the GPD firmware sends as Menu+R1) takes screenshots.
#
# Steam's stock Xbox chord layout puts Screenshot on Guide + right *trigger*, which the GPD V2
# firmware cannot emit from a macro slot (known bug). Steam's own "Guide Button Chord Layout"
# editor on non-Deck installs sometimes does not persist, so this patches the base layout files
# directly. Steam client updates may replace them; just re-run this script (it is idempotent).
# Run as your normal user with Steam closed, or restart Steam afterwards.
set -euo pipefail
BASE="${STEAM_ROOT:-$HOME/.local/share/Steam}/controller_base"
for f in chord.vdf chord_xboxone.vdf; do
  p="$BASE/$f"
  [[ -f "$p" ]] || { echo "missing $p"; continue; }
  if grep -q 'controller_action SCREENSHOT' <(grep -A8 '"right_bumper"' "$p"); then
    echo "$f: already patched"; continue
  fi
  cp -a "$p" "$p.orig-$(date +%Y%m%d)"
  python3 - "$p" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
m = re.search(r'("right_bumper"\s*\{\s*"activators"\s*\{\s*"Full_Press"\s*\{\s*"bindings"\s*\{\s*"binding"\s*)"mouse_button LEFT"', s)
if not m:
    sys.exit(f"{p}: right_bumper block not in the expected form; not touching it")
open(p, "w").write(s[:m.start()] + m.group(1) + '"controller_action SCREENSHOT"' + s[m.end():])
print(f"{p.split('/')[-1]}: Guide+RB -> Take Screenshot")
PY
done
echo "restart Steam (or switch session) to load the new chord layout"
