#!/usr/bin/bash
# Map the GPD back buttons to Steam *gamepad chords* (not keyboard keys):
#   L4 = Menu + R1   -> Steam screenshot   (bind Guide+R1 to "Take Screenshot" in Steam's
#                                           Guide Button Chord Layout; see README)
#   R4 = Menu + A    -> Quick Access Menu  (the "..." side tray)
# Chords are consumed by Steam Input as system shortcuts, so unlike keyboard macros
# nothing leaks into the running game. The Menu button alone still opens the Steam menu.
# Needs OpenWinControlsCLI (AUR: openwincontrolscli-git). Writes to the controller's own memory,
# so the mapping persists across reboots and also applies under Windows.
set -euo pipefail
command -v OpenWinControlsCLI >/dev/null || { echo "OpenWinControlsCLI not found (AUR: openwincontrolscli-git)"; exit 1; }

backup="${XDG_DOCUMENTS_DIR:-$HOME/Documents}/gpd-controller-config-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$backup")"
echo "==> saving current controller config to $backup"
OpenWinControlsCLI print > "$backup"
grep -E 'Version' "$backup" || true

echo "==> writing L4 = Menu+R1 (screenshot chord), R4 = Menu+A (Quick Access Menu)"
# l4d/r4d = start offset per key (ms), l4h/r4h = hold time per key (ms).
# Menu is held 400 ms; the second button lands 100 ms in and releases first, so Steam sees a
# chord rather than a plain Menu tap.
# Note: the V2 firmware ignores LT/RT (R2/L2) in macro slots, so a trigger chord is not possible.
OpenWinControlsCLI set l4 MENU,R1 l4d 0,100 l4h 400,200 r4 MENU,BTN_A r4d 0,100 r4h 400,200

echo "==> result"
OpenWinControlsCLI print | awk '/=== L4 Back Button ===/,/=== L5 Back Button ===/' | grep -vE 'UNSET|Time:\s+0$|^$|L5'
