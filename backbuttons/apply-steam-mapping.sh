#!/usr/bin/bash
# Map the GPD back buttons to Steam-friendly keys:
#   L4 = F12             (Steam's default screenshot key)
#   R4 = Ctrl+Shift+Tab  (Steam's Quick Access Menu hotkey; the "..." side tray)
# The Menu button on the controller already opens the Steam menu, so neither is wasted on that.
# Needs OpenWinControlsCLI (AUR: openwincontrolscli-git). Writes to the controller's own memory,
# so the mapping persists across reboots and also applies under Windows.
set -euo pipefail
command -v OpenWinControlsCLI >/dev/null || { echo "OpenWinControlsCLI not found (AUR: openwincontrolscli-git)"; exit 1; }

backup="${XDG_DOCUMENTS_DIR:-$HOME/Documents}/gpd-controller-config-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$backup")"
echo "==> saving current controller config to $backup"
OpenWinControlsCLI print > "$backup"
grep -E 'Version' "$backup" || true

echo "==> writing L4 = F12, R4 = Ctrl+Shift+Tab"
# l4d/r4d = start offset per key (ms), l4h/r4h = hold time per key (ms).
# Tab starts 40 ms after the modifiers and releases while they are still held -> a real chord.
OpenWinControlsCLI set l4 F12 l4d 0 l4h 120 r4 LEFTCTRL,LEFTSHIFT,TAB r4d 0,0,40 r4h 220,220,120

echo "==> result"
OpenWinControlsCLI print | awk '/=== L4 Back Button ===/,/=== L5 Back Button ===/' | grep -vE 'UNSET|Time:\s+0$|^$|L5'
