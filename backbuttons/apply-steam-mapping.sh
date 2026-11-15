#!/usr/bin/bash
# Map the GPD back buttons:
#   L4 = F13         -> gamescope screenshot via gamescope-screenshot-key.service (see README)
#   R4 = Menu + A    -> Steam Quick Access Menu (gamepad chord, the "..." side tray)
# Why not Steam's own screenshot chord: it is Guide + RT and the V2 firmware cannot pull a
# trigger from a macro; Guide + R1 is a mouse click in Steam's layout and Steam reverts edits
# to its layout files. F13 is a key no game uses, so it is safe to send to the game as well.
# Needs OpenWinControlsCLI (AUR: openwincontrolscli-git). Writes to the controller's own memory,
# so the mapping persists across reboots and also applies under Windows.
set -euo pipefail
command -v OpenWinControlsCLI >/dev/null || { echo "OpenWinControlsCLI not found (AUR: openwincontrolscli-git)"; exit 1; }

backup="${XDG_DOCUMENTS_DIR:-$HOME/Documents}/gpd-controller-config-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$backup")"
echo "==> saving current controller config to $backup"
OpenWinControlsCLI print > "$backup"
grep -E 'Version' "$backup" || true

echo "==> writing L4 = F13 (gamescope screenshot), R4 = Menu+A (Quick Access Menu)"
# l4d/r4d = start offset per key (ms), l4h/r4h = hold time per key (ms).
# R4: Menu is held 400 ms; A lands 100 ms in and releases first, so Steam sees a chord rather
# than a plain Menu tap.
OpenWinControlsCLI set l4 F13 l4d 0 l4h 100 r4 MENU,BTN_A r4d 0,100 r4h 400,200

echo "==> result"
OpenWinControlsCLI print | awk '/=== L4 Back Button ===/,/=== L5 Back Button ===/' | grep -vE 'UNSET|Time:\s+0$|^$|L5'
