# GPD WIN Mini (2025) on CachyOS: handheld extras

Small fixes and tools for running CachyOS (Plasma desktop + gamescope "SteamOS mode")
on the GPD WIN Mini 2025 (Ryzen AI 9 HX 370 / AI 9 365). Most of it should apply to
other GPD handhelds and to any AMD handheld that lacks a vendor TDP driver.

Two problems are solved here:

1. **Tap-to-click does nothing in gamescope.** gamescope has no libinput configuration,
   so touchpad taps are never turned into clicks (upstream PR
   [ValveSoftware/gamescope#1406](https://github.com/ValveSoftware/gamescope/pull/1406)
   is still open). Plasma works because KWin enables tapping itself.
2. **No sane way to control TDP.** GPD exposes no firmware-attribute or `power1_cap`
   path, and the AMD PMF tables in the BIOS are empty, so nothing in the kernel can set a
   power limit. Userspace has to talk to the SMU via [RyzenAdj](https://github.com/FlyGoat/RyzenAdj),
   which needs `iomem=relaxed` on the kernel command line. Without a limit the HX 370 can
   pull toward its 54 W firmware ceiling and hard power-off the device under load.

## What's inside

| Path | What it does |
|---|---|
| `touchpad/gamescope-tap-to-click` | Watches the touchpad (read-only) and emits left/right/middle clicks for 1/2/3-finger taps through a virtual uinput mouse. Runs only inside the gamescope session, so KWin's own tapping is untouched on the desktop. |
| `tdp/tdpctl` | Root helper: `status`, `set-tdp <W>` (5–35), `set-boost 0/1`, `set-fan quiet/normal`. Everything else calls this. |
| `tdp/gpd-fan-quiet` | Gentler fan curve using the kernel `gpd-fan` driver's manual PWM mode (~1200 rpm idle vs ~4000 rpm for the EC curve). Hands control back to the EC on exit or crash. |
| `tdp/steamos-tdp-provider` | System-bus D-Bus service implementing Valve's `TdpLimit1` interface. Registered with steamos-manager as a *remote interface*, which makes **Steam's native TDP slider** work in gamescope with no patched binaries and no Decky plugin. |
| `plasmoid/` | Plasma 6 panel widget: TDP slider, four presets, CPU boost switch, fan Normal/Quiet, live power/temp/rpm readout. Reads the real limit from the chip, so it always agrees with Steam. |
| `install.sh` / `uninstall.sh` | Idempotent installer; substitutes your username into the sudoers and D-Bus policy files. |

## Requirements

- CachyOS (or any Arch-based distro) with `gamescope-session`, Plasma 6, systemd, dbus.
- `steamos-manager` from the CachyOS repo (installed by `install.sh`).
- **ryzenadj** in `PATH` or `/usr/local/bin`. Not in the CachyOS repos; build it:
  ```sh
  sudo pacman -S cmake
  git clone https://github.com/FlyGoat/RyzenAdj && cd RyzenAdj
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
  sudo install -m755 build/ryzenadj /usr/local/bin/
  sudo install -m755 build/libryzenadj.so /usr/local/lib/ && sudo ldconfig
  ```
- **`iomem=relaxed`** on the kernel command line (CachyOS kernels build with
  `CONFIG_STRICT_DEVMEM`, which otherwise blocks ryzenadj's `/dev/mem` access).
  Limine (CachyOS default):
  ```sh
  sudo sed -i 's/^\(KERNEL_CMDLINE\[default\]+="[^"]*\)"/\1 iomem=relaxed"/' /etc/default/limine
  sudo limine-update && sudo reboot
  ```
  GRUB: add it to `GRUB_CMDLINE_LINUX_DEFAULT` and run `grub-mkconfig -o /boot/grub/grub.cfg`.

## Install

```sh
git clone <this repo> && cd gpd-win-mini-cachyos
sudo ./install.sh            # both parts; or --touchpad / --tdp
```

Then:

- **Steam slider:** switch to SteamOS mode (or restart Steam). Steam probes steamos-manager
  only at startup, so the provider must be running first; the installer enables it at boot.
  Quick Access → Performance now shows *TDP Limit*. Toggling it off sets 35 W, not the
  firmware ceiling.
- **KDE widget:** Edit Mode → Add Widgets → *TDP Control*. Presets are editable in the
  widget settings.
- **Check from a terminal:** `steamosctl get-tdp-limit`, `sudo tdpctl status`.

## How the TDP path fits together

```
Steam (gamepad UI) ──D-Bus──▶ steamos-manager (user) ──relay──▶ steamos-tdp-provider (root)
                                                                       │
KDE widget ──sudo──▶ tdpctl ◀──────────────────────────────────────────┘
                       │
                    ryzenadj ──/dev/mem──▶ SMU (STAPM / PPT fast / PPT slow, tctl 90 °C)
```

Both front ends read the limit back from the hardware every few seconds, so a change made
in one shows up in the other.

## Things worth knowing

- **35 W cap.** That is GPD's own ceiling for this model and about where the chassis stops
  being able to cool. Change `TDP_MIN`/`TDP_MAX` at the top of `tdpctl` and the widget's
  preset spinbox limits if you really want more.
- **Keep Steam's "Manual GPU Clock Control" off.** On an APU the TDP is one shared budget;
  a pinned GPU clock gets first claim on it and starves the CPU. Steam re-applies that
  setting at every start. The device config in `tdp/steamos-manager/devices/` gives
  steamos-manager the correct 600–2900 MHz range so the control at least behaves if you do
  use it.
- **PowerControl / SimpleDeckyTDP** will fight this setup. Disable their TDP control or
  remove them.
- **Fan quiet mode** is a userspace curve: `(45 °C, 25) (55, 40) (65, 70) (75, 110) (82, 160)
  (88, 215) (92, 255)` on a 0–255 PWM scale, with full speed forced above 95 °C. Spin-up is
  instant, spin-down is gradual. Edit `CURVE` in `gpd-fan-quiet` to taste.
- **Security notes.** `tdpctl` is the only thing granted passwordless sudo, it is root-owned,
  and it validates every argument. The read-only `tdpctl status` poll is excluded from the
  sudo syslog so the widget does not spam the journal; changes are still logged. The D-Bus
  policy only lets root and your user talk to the provider. The touchpad shim needs read
  access to the touchpad event node, granted via a `uaccess` udev tag (seat user only).
- **Updates.** Everything lives under `/etc`, `/usr/local` or in files the distro packages
  do not own, so package updates leave it alone. Kernel updates are the thing to watch: if
  ryzenadj ever loses SMU access the widget will show the error.

## Tested on

GPD WIN Mini 2025 (G1617-02, HX 370), CachyOS, linux-cachyos 7.3, Plasma 6.8,
gamescope 3.17, steamos-manager 26.4.1, RyzenAdj 0.19.0.

## Credits

[RyzenAdj](https://github.com/FlyGoat/RyzenAdj) (FlyGoat and contributors),
Valve's [steamos-manager](https://gitlab.steamos.cloud/holo/steamos-manager) and its
remote-interface mechanism, the kernel `gpd-fan` driver (Cryolitia PukNgae), and the
[hhd](https://github.com/hhd-dev/hhd) / [PowerControl](https://github.com/mengmeet/PowerControl)
projects whose approaches informed this.
