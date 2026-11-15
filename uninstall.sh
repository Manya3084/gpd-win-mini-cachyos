#!/usr/bin/bash
# Remove everything install.sh put in place (ryzenadj and the iomem=relaxed flag are left alone).
set -uo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
TARGET_USER="${SUDO_USER:-${1:-}}"
systemctl --global disable gamescope-tap-to-click.service 2>/dev/null
rm -f /usr/local/bin/gamescope-tap-to-click /etc/systemd/user/gamescope-tap-to-click.service /etc/udev/rules.d/71-touchpad-uaccess.rules
systemctl disable --now tdp-fan-quiet.service steamos-tdp-provider.service 2>/dev/null
/usr/local/bin/gpd-fan-quiet --restore 2>/dev/null
rm -f /usr/local/bin/tdpctl /usr/local/bin/gpd-fan-quiet /usr/local/bin/steamos-tdp-provider
rm -f /etc/systemd/system/tdp-fan-quiet.service /etc/systemd/system/steamos-tdp-provider.service
rm -f /etc/sudoers.d/tdpctl /etc/dbus-1/system.d/org.cachyos.TdpProvider.conf
rm -f /etc/steamos-manager/remotes.d/10-gpd-tdp.toml /usr/share/steamos-manager/devices/gpd-win-mini-2025.toml
systemctl daemon-reload; udevadm control --reload
systemctl restart steamos-manager.service 2>/dev/null
if [[ -n "$TARGET_USER" && "$TARGET_USER" != root ]]; then
  runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="/run/user/$(id -u "$TARGET_USER")" kpackagetool6 -t Plasma/Applet -r org.cachyos.tdpcontrol 2>/dev/null
fi
echo "removed. steamos-manager package, ryzenadj and the kernel cmdline were left in place."
