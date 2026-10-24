# lp-w841_linux

Turning the **Wearness LP-W841** into a usable Linux tablet.
Umm.., basically my device been taking dust since 2023, because I forgot to dump the silead firmware from its default windows installation. But finally someone did it, you can found it at [onitake/gsl-firmware](https://github.com/onitake/gsl-firmware/tree/master/firmware/mytab/Garda_U80GT), its turn out to be the same devices.

You may want to just skip to the [Touchscreen](docs/02-touchscreen-silead.md) part.

The LP-W841 is a Bay Trail tablet (Insyde firmware, Intel Atom Z3735, 1 GB RAM,
16 GB eMMC, 800x1280 portrait panel). Out of the box it is not usable: there is
no touchscreen support, the panel backlight is not exposed, the audio codec
needs extra firmware, and the machine is tight on memory.

This repo is the **device-level** half of the setup: how to install Debian on
it and make the hardware work - touchscreen, display, backlight, audio, power,
gamepad, memory tuning and the kernel quirks. It contains the exact
configuration files, the touchscreen firmware, and the documentation with the
collected evidence.

> The **desktop** (sway, waybar, on-screen keyboard, touch apps, accent theme)
> is a separate repo: **[`cicag/sway-tablet`](https://github.com/cicag/sway-tablet)**.

---

## Hardware

| | |
|---|---|
| Device | Wearness LP-W841 (Baytrail tablet, Insyde firmware, 32-bit UEFI) |
| CPU | Intel Atom Z3735 (Bay Trail-T), 4 cores, x86-64 |
| RAM | 1 GB (882 MB usable) |
| Storage | 14.7 GB eMMC (`/dev/mmcblk1`), root on F2FS |
| GPU | Intel HD Graphics (Bay Trail), driver `i915` |
| Display | DSI-1, 800x1280 (portrait) |
| Touchscreen | Silead **MSSL1680** (I2C, ACPI `MSSL1680`) -> input `silead_ts` |
| Audio | Realtek ALC5640 `bytcr-rt5640` + Intel SST (`fw_sst_0f28`) |
| WiFi/BT | Realtek **RTL8723BS** (SDIO + UART H5, combined chip) |
| PMIC | X-Powers **AXP288** (`INT33F4`); power key `axp20x-pek` |
| Sensors | Bosch `BMA250E` accelerometer |
| Backlight | `intel_backlight` (PWM) |

See [docs/00-hardware.md](docs/00-hardware.md) for details.

## What works after the setup

- **Touchscreen** with the right orientation and a calibration matrix, so taps
  land where they should.
- **Display** at the native DSI-1 mode, with a working **backlight**.
- **Audio** (codec + Intel SST firmware) and **audio/sound keys**.
- **Power button** (short press: screen on/off, long press: power dialog) and
  battery reporting.
- **Bluetooth gamepad** (DualShock 4) and WiFi.
- **Memory tuning**: zram swap, log2ram, trimmed journald - the tablet is
  comfortable with a desktop session in under 900 MB of RAM.
- Boot straight into the session (getty autologin on tty1), no display manager.

## Quick start

1. **Install Debian 12 (bookworm) amd64** on the tablet - the 32-bit UEFI
   bootloader needs a FAT ESP with the right EFI flags
   ([docs/01-debian-install.md](docs/01-debian-install.md)).
2. **Apply the configuration**:
   ```sh
   sudo ./install.sh
   ```
   The script copies `config/etc/` over `/etc` and the touchscreen firmware
   into `/lib/firmware/silead/`. `/etc/fstab` is **not** copied because its
   UUIDs are machine-specific - see `reference/fstab.example`.
3. **Reboot**, then follow the per-topic docs below to verify each part.

The kernel matters: use Debian 12's stock **6.1** kernel. On 6.12+ the
touchscreen is no longer enumerated over ACPI I2C - the details are in
[docs/07-troubleshooting.md](docs/07-troubleshooting.md).

## Documentation index

| Doc | Contents |
|---|---|
| [docs/00-hardware.md](docs/00-hardware.md) | Device overview, component list, firmware |
| [docs/01-debian-install.md](docs/01-debian-install.md) | Base install, partitioning, 32-bit UEFI, packages |
| [docs/02-touchscreen-silead.md](docs/02-touchscreen-silead.md) | Silead touch: firmware, calibration, applying it, Debian 13 anomaly |
| [docs/03-display-backlight.md](docs/03-display-backlight.md) | Panel, backlight permissions, audio env |
| [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | zram, log2ram, sysctl, kernel cmdline, trimming |
| [docs/05-input-gamepad.md](docs/05-input-gamepad.md) | DualShock 4 over Bluetooth, input modules/permissions |
| [docs/06-vulkan-renderer-backport.md](docs/06-vulkan-renderer-backport.md) | Building wlroots 0.16.2 + sway 1.8.1 with Vulkan |
| [docs/07-troubleshooting.md](docs/07-troubleshooting.md) | Known errors and fixes (touch, Bluetooth race, kernel) |

The desktop setup (sway/waybar/OSK/touch apps) is documented in
**[sway-tablet/docs](https://github.com/cicag/sway-tablet/tree/main/docs)**.

## Repository layout

```
config/           exact copies of the on-device system configs
  etc/            -> /etc/...
  sudoers/        installed atomically (validated with visudo)
firmware/         touchscreen firmware (mssl1680.fw)
docs/             the documentation
reference/        raw collected system/input/firmware info (evidence),
                  plus fstab.example (template, UUIDs to fill in)
install.sh        copies config/ and firmware/ onto the device
```

> Files under `config/etc/` mirror the on-device absolute paths. To restore,
> copy `config/etc/*` over `/etc/*`.

## Raw evidence

The `reference/` directory contains unedited dumps taken from the device
(`system-info.txt`, `root-info.txt`, `01-input-devices.txt`,
`04-dmesg-silead.txt`, the Silead calibration corner taps in `corners-evt.txt`,
...). These are the source of truth for the numbers quoted in the docs.
