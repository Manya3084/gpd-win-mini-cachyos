#!/usr/bin/bash
# Map the GPD back buttons to Steam-friendly keys:
#   L4 = Shift+Tab  (Steam overlay in games, Steam menu in the gamepad UI)
#   R4 = F12        (Steam's default screenshot key)
# Needs OpenWinControlsCLI (AUR: openwincontrolscli-git). Writes to the controller's own memory,
# so the mapping persists across reboots and also applies under Windows.
set -euo pipefail
command -v OpenWinControlsCLI >/dev/null || { echo "OpenWinControlsCLI not found (AUR: openwincontrolscli-git)"; exit 1; }

backup="${XDG_DOCUMENTS_DIR:-$HOME/Documents}/gpd-controller-config-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$backup")"
echo "==> saving current controller config to $backup"
OpenWinControlsCLI print > "$backup"
grep -E 'Version' "$backup" || true

echo "==> writing L4 = Shift+Tab, R4 = F12"
# l4d/r4d = start offset per key (ms), l4h/r4h = hold time per key (ms).
# Tab starts 40 ms after Shift and releases while Shift is still held -> a real chord.
OpenWinControlsCLI set l4 LEFTSHIFT,TAB l4d 0,40 l4h 220,120 r4 F12 r4d 0 r4h 120

echo "==> result"
OpenWinControlsCLI print | awk '/=== L4 Back Button ===/,/=== L5 Back Button ===/' | grep -vE 'UNSET|Time:\s+0$|^$|L5'
