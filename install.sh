#!/usr/bin/bash
# Installer for the GPD WIN Mini (2025) CachyOS extras.
# Run as root from the repo root:  sudo ./install.sh [--touchpad|--tdp|--all] [--user NAME]
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${SUDO_USER:-}"
DO_TOUCHPAD=0; DO_TDP=0

usage() { sed -n '2,3p' "$0"; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --touchpad) DO_TOUCHPAD=1 ;;
    --tdp)      DO_TDP=1 ;;
    --all)      DO_TOUCHPAD=1; DO_TDP=1 ;;
    --user)     TARGET_USER="$2"; shift ;;
    -h|--help)  usage ;;
    *) echo "unknown option: $1"; usage 1 ;;
  esac; shift
done
[[ $DO_TOUCHPAD -eq 0 && $DO_TDP -eq 0 ]] && { DO_TOUCHPAD=1; DO_TDP=1; }
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
[[ -n "$TARGET_USER" && "$TARGET_USER" != root ]] || { echo "pass --user <your login> (could not infer from sudo)"; exit 1; }
id "$TARGET_USER" >/dev/null
USER_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
USER_UID="$(id -u "$TARGET_USER")"
as_user() { runuser -u "$TARGET_USER" -- env XDG_RUNTIME_DIR="/run/user/$USER_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_UID/bus" "$@"; }

echo "==> target user: $TARGET_USER"

if [[ $DO_TOUCHPAD -eq 1 ]]; then
  echo "==> touchpad: gamescope tap-to-click shim"
  pacman -S --needed --noconfirm python-evdev >/dev/null
  install -m 755 "$HERE/touchpad/gamescope-tap-to-click" /usr/local/bin/gamescope-tap-to-click
  install -m 644 "$HERE/touchpad/71-touchpad-uaccess.rules" /etc/udev/rules.d/71-touchpad-uaccess.rules
  install -m 644 "$HERE/touchpad/gamescope-tap-to-click.service" /etc/systemd/user/gamescope-tap-to-click.service
  udevadm control --reload; udevadm trigger --action=add --subsystem-match=input
  systemctl --global enable gamescope-tap-to-click.service
  echo "    starts with the next gamescope session"
fi

if [[ $DO_TDP -eq 1 ]]; then
  echo "==> tdp: helper, fan curve, Steam slider provider, KDE widget"
  pacman -S --needed --noconfirm steamos-manager python-gobject >/dev/null
  install -m 755 "$HERE/tdp/tdpctl" /usr/local/bin/tdpctl
  install -m 755 "$HERE/tdp/gpd-fan-quiet" /usr/local/bin/gpd-fan-quiet
  install -m 755 "$HERE/tdp/steamos-tdp-provider" /usr/local/bin/steamos-tdp-provider
  install -m 644 "$HERE/tdp/systemd/tdp-fan-quiet.service" /etc/systemd/system/
  install -m 644 "$HERE/tdp/systemd/steamos-tdp-provider.service" /etc/systemd/system/
  sed "s/@USER@/$TARGET_USER/g" "$HERE/tdp/sudoers.d/tdpctl" > /etc/sudoers.d/tdpctl
  chmod 440 /etc/sudoers.d/tdpctl; visudo -cf /etc/sudoers.d/tdpctl >/dev/null
  sed "s/@USER@/$TARGET_USER/g" "$HERE/tdp/dbus/org.cachyos.TdpProvider.conf" > /etc/dbus-1/system.d/org.cachyos.TdpProvider.conf
  mkdir -p /etc/steamos-manager/remotes.d
  install -m 644 "$HERE/tdp/steamos-manager/remotes.d/10-gpd-tdp.toml" /etc/steamos-manager/remotes.d/
  install -m 644 "$HERE/tdp/steamos-manager/devices/gpd-win-mini-2025.toml" /usr/share/steamos-manager/devices/
  systemctl daemon-reload
  systemctl reload dbus 2>/dev/null || systemctl reload dbus-broker 2>/dev/null || true
  systemctl enable --now steamos-manager.service steamos-tdp-provider.service
  systemctl restart steamos-manager.service steamos-tdp-provider.service

  echo "==> installing KDE widget for $TARGET_USER"
  if as_user kpackagetool6 -t Plasma/Applet -l 2>/dev/null | grep -q org.cachyos.tdpcontrol; then
    as_user kpackagetool6 -t Plasma/Applet -u "$HERE/plasmoid" >/dev/null
  else
    as_user kpackagetool6 -t Plasma/Applet -i "$HERE/plasmoid" >/dev/null
  fi
  echo "    add 'TDP Control' to a panel via Edit Mode > Add Widgets (or restart plasmashell if updating)"

  echo
  if ! command -v ryzenadj >/dev/null && [[ ! -x /usr/local/bin/ryzenadj ]]; then
    echo "!!  ryzenadj not found. Build it (see README 'ryzenadj'):"
    echo "    pacman -S cmake && git clone https://github.com/FlyGoat/RyzenAdj && cd RyzenAdj"
    echo "    cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build"
    echo "    sudo install -m755 build/ryzenadj /usr/local/bin/ && sudo install -m755 build/libryzenadj.so /usr/local/lib/ && sudo ldconfig"
  fi
  if ! grep -qw 'iomem=relaxed' /proc/cmdline; then
    echo "!!  kernel cmdline lacks iomem=relaxed; ryzenadj cannot reach the SMU without it."
    echo "    Limine (CachyOS default): append ' iomem=relaxed' to KERNEL_CMDLINE[default] in /etc/default/limine,"
    echo "    then run: sudo limine-update   and reboot.  (GRUB: GRUB_CMDLINE_LINUX_DEFAULT + grub-mkconfig)"
  fi
fi
echo "==> done"
