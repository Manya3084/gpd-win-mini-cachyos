# GPD WIN Mini (2025) on CachyOS: handheld extras

Small fixes and tools for running CachyOS (Plasma desktop + gamescope "SteamOS mode")
on the GPD WIN Mini 2025 (Ryzen AI 9 HX 370 / AI 9 365). Most of it should apply to
other GPD handhelds and to any AMD handheld that lacks a vendor TDP driver.

Three problems are solved here:

1. **Tap-to-click does nothing in gamescope.** gamescope has no libinput configuration,
   so touchpad taps are never turned into clicks (upstream PR
   [ValveSoftware/gamescope#1406](https://github.com/ValveSoftware/gamescope/pull/1406)
   is still open). Plasma works because KWin enables tapping itself.
2. **No sane way to control TDP.** GPD exposes no firmware-attribute or `power1_cap`
   path, and the AMD PMF tables in the BIOS are empty, so nothing in the kernel can set a
   power limit. Userspace has to talk to the SMU via [RyzenAdj](https://github.com/FlyGoat/RyzenAdj),
   which needs `iomem=relaxed` on the kernel command line. Without a limit the HX 370 can
   pull toward its 54 W firmware ceiling and hard power-off the device under load.
3. **The L4 / R4 back buttons seem dead.** They are keyboard macro keys, and the 2025 unit
   ships with a placeholder `A B C D` macro in every slot. Nothing is broken; they just need a
   real mapping written to the controller.

## What's inside

| Path | What it does |
|---|---|
| `touchpad/gamescope-tap-to-click` | Watches the touchpad (read-only) and emits left/right/middle clicks for 1/2/3-finger taps through a virtual uinput mouse. Runs only inside the gamescope session, so KWin's own tapping is untouched on the desktop. |
| `tdp/tdpctl` | Root helper: `status`, `set-tdp <W>` (5–35), `set-boost 0/1`, `set-fan quiet/normal`. Everything else calls this. |
| `tdp/gpd-fan-quiet` | Gentler fan curve using the kernel `gpd-fan` driver's manual PWM mode (~1200 rpm idle vs ~4000 rpm for the EC curve). Hands control back to the EC on exit or crash. |
| `tdp/steamos-tdp-provider` | System-bus D-Bus service implementing Valve's `TdpLimit1` interface. Registered with steamos-manager as a *remote interface*, which makes **Steam's native TDP slider** work in gamescope with no patched binaries and no Decky plugin. |
| `plasmoid/` | Plasma 6 panel widget: TDP slider, four presets, CPU boost switch, fan Normal/Quiet, live power/temp/rpm readout. Reads the real limit from the chip, so it always agrees with Steam. |
| `backbuttons/` | udev rule for the controller's WinControls interface and a script that maps L4 = F12 (screenshot), R4 = Ctrl+Shift+Tab (Quick Access Menu) with OpenWinControlsCLI. |
| `pkg/ryzenadj/` | PKGBUILD for [RyzenAdj](https://github.com/FlyGoat/RyzenAdj), pinned to a tagged release with checksum. |
| `install.sh` / `uninstall.sh` | Idempotent installer; substitutes your username into the sudoers and D-Bus policy files. |

## Requirements

- CachyOS (or any Arch-based distro) with `gamescope-session`, Plasma 6, systemd, dbus.
- `steamos-manager` from the CachyOS repo (installed by `install.sh`).
- **ryzenadj**. Not in the CachyOS repos; a PKGBUILD pinned to the current release is
  included, so it installs as a normal pacman package:
  ```sh
  cd pkg/ryzenadj && makepkg -si      # installs /usr/bin/ryzenadj
  ```
  (`tdpctl` also accepts a manual copy in `/usr/local/bin`.)
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

## L4 / R4 back buttons

The controller hub shows up as four USB devices: the gamepad, a mouse, a keyboard and a
"Vendor for Windows" interface (`2f24:0137` on the 2025 model). The back buttons are **not
gamepad buttons**: each one plays a macro of up to 32 keyboard/mouse keys through the keyboard
interface, and the vendor interface is where that macro is programmed. Out of the box every
macro slot holds `A B C D` with odd timings, so pressing L4 or R4 types "abcd" into whatever
has focus, which in Steam looks like nothing at all.

**Firmware first.** Early 2025 units shipped with controller firmware on which the back buttons
did not work at all. Update with GPD's *WinControls v2.08 + WIN Mini 2025 controller firmware
v1.24* package from the [GPD download page](https://www.gpd.hk/gpdwinmini2025firmwaredriver).
The updater is Windows-only, so do it from a Windows install or a Windows-To-Go stick before
expecting anything below to help. You can check what you have from Linux:

```sh
OpenWinControlsCLI print | head -5     # expect "Keyboard&Mouse Version: 1.24" or newer
```

**Install the tooling** (the GUI `openwincontrols-git` works too; the CLI is scriptable):

```sh
sudo ./install.sh --backbuttons        # udev rule so the CLI works without sudo
git clone https://aur.archlinux.org/openwincontrolscli-git.git && cd openwincontrolscli-git && makepkg -si
```

**Apply the Steam-friendly mapping**: L4 = F12 (Steam screenshot), R4 = Ctrl+Shift+Tab
(Steam's Quick Access Menu hotkey, the "..." tray on the right). The controller's Menu button
already opens the Steam menu, so the back buttons cover the two things it does not. The script
saves the current config to `~/Documents` first:

```sh
./backbuttons/apply-steam-mapping.sh
```

Or roll your own, e.g. F13/F14 to bind per game inside Steam Input:

```sh
OpenWinControlsCLI keys                                   # list of accepted key names
OpenWinControlsCLI set l4 F13 l4d 0 l4h 100 r4 F14 r4d 0 r4h 100
```

Verify by pressing the buttons while watching `sudo libinput debug-events` or `evtest` on the
"Keyboard for Windows" device.

Notes:
- The mapping is stored in the controller, so it persists across reboots and applies under
  Windows as well.
- `l4d`/`r4d` are per-key start offsets and `l4h`/`r4h` per-key hold times, in ms. For a chord,
  start the modifiers first and release them last (the script holds Ctrl and Shift 0–220 ms
  and taps Tab 40–160 ms).
- Steam hotkeys in the gamepad UI: Ctrl+Shift+Tab opens the Quick Access Menu and Shift+Tab
  the Steam menu, in and out of games on current Steam clients (older clients only honoured
  Ctrl+1 / Ctrl+2 outside of games). If your client ignores them, update Steam or check
  Settings for the configurable hotkeys.
  Hold times over ~150 ms make the kernel emit a key auto-repeat; harmless for most keys.
- Slots beyond the active count keep whatever stale keys were there; the firmware ignores them.
- CLI 2.10's `export` exits 0 without writing a file; back up with `OpenWinControlsCLI print > file`.
- Handheld Daemon also speaks this protocol (its "WinControls" tab) if you go that route for
  controller emulation.

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
