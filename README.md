# lp-w841_linux

Turning the **Wearness LP-W841** into a usable Linux tablet.
Accidentaly bricked this device because I forgot to dump the Silead touchscreen firmware from the original Windows installation. Fortunately, someone did it, you can find a compatible firmware in [onitake/gsl-firmware](https://github.com/onitake/gsl-firmware/tree/master/firmware/mytab/Garda_U80GT)
(the Garda U80GT entry uses the same hardware); the exact provenance is in
[`firmware/NOTICE`](firmware/NOTICE).

You may want to skip to the [Touchscreen](#touchscreen-mssl1680) part, the other
hardware tweaks are optional.

## Hardware

| Item | Value |
|---|---|
| Device | Wearness LP-W841 (Bay Trail tablet, Insyde 32-bit UEFI) |
| CPU | Intel Atom Z3735, 4 cores, x86-64 |
| RAM | 1 GB (882 MB usable) |
| Storage | 14.7 GB eMMC (`/dev/mmcblk1`) |
| GPU | Intel HD Graphics (Bay Trail), `i915` |
| Display | DSI-1, 800x1280 (portrait) |
| Touchscreen | Silead **MSSL1680** (I2C, ACPI `MSSL1680`) → `silead_ts` |
| Audio | Realtek ALC5640 `bytcr-rt5640` + Intel SST (`fw_sst_0f28`) |
| WiFi/BT | Realtek **RTL8723BS** (SDIO + UART H5) |
| PMIC | X-Powers **AXP288** (`INT33F4`); power key `axp20x-pek` |
| Sensors | Bosch `BMA250E` accelerometer |
| Backlight | `intel_backlight` (PWM) |

## Requirements

### Base system
- **Debian 12 or Debian 13 amd64** with a 32-bit UEFI bootloader ([docs/01-debian-install.md](docs/01-debian-install.md)), or your distro choice.
- **Kernel 6.1 required for Silead touchscreen.** Debian 12 ships 6.1; on Debian 13 (trixie) you must downgrade/pin the kernel to 6.1. On 6.12+ the touchscreen fails to enumerate.
- Root/sudo access.

## Touchscreen (MSSL1680)

The touchscreen is not usable out of the box. The digitizer is transposed and needs firmware and a libinput calibration matrix.

### Quick apply
```sh
# 1) Install firmware (from this repo)
sudo install -Dm644 firmware/mssl1680.fw /lib/firmware/silead/mssl1680.fw

# 2) Install calibration udev rule
sudo install -Dm644 config/etc/udev/rules.d/99-silead-calibration.rules \
  /etc/udev/rules.d/99-silead-calibration.rules

# 3) Reload udev and trigger
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input --action=change

# 4) Load/reload the driver
sudo modprobe -r silead && sudo modprobe silead

# 5) Verify
./verify.sh
```

### Notes
- Calibration details and the matrix rationale: [docs/02-touchscreen-silead.md](docs/02-touchscreen-silead.md).
- Mapping to a specific output/rotation depends on your display server/compositor and is outside this repo. For a minimalist sway setup tuned for this touchscreen, see [`cicag/sway-tablet`](https://github.com/cicag/sway-tablet).
- Want to calibrate touchscreen yourself? try [cicag/kalibret](https://github.com/cicag/kalibret)

## Documentation
| Doc | Contents |
|---|---|
| [docs/01-debian-install.md](docs/01-debian-install.md) | Base install, partitioning, 32-bit UEFI, packages, sources |
| [docs/02-touchscreen-silead.md](docs/02-touchscreen-silead.md) | Silead MSSL1680: firmware, calibration, applying, Debian 13 anomaly |
| [docs/03-display-backlight.md](docs/03-display-backlight.md) | Panel, backlight permissions, i915, VA-API, audio |
| [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | zram, log2ram, sysctl, kernel cmdline, trimming |
| [docs/05-troubleshooting.md](docs/05-troubleshooting.md) | Known errors and fixes (touch, kernel, audio) |

## Repository layout
```
config/           Optional on-device system configs (copy only what you need)
  etc/            Mirrors /etc/...
firmware/         Touchscreen firmware (mssl1680.fw) + NOTICE (provenance)
docs/             Documentation
reference/        Unedited device dumps and templates (e.g. fstab.example)
verify.sh         Read-only touchscreen health check
```

## Credits and firmware attribution
The touchscreen firmware comes from the **onitake/gsl-firmware** project, entry `firmware/mytab/Garda_U80GT`, commit `dbaac009452f8a4810d02517d5f8e748fefccb2a`. The local file is a byte-for-byte copy of `firmware_00.fw` (SHA256 `69334fc1a8febbaf74efa92ff870f39ff5f84d7f819993fe35f878ab78c3cfe2`), renamed to `mssl1680.fw` as the Linux `silead` driver expects. This is proprietary/unknown-licensed third-party material; the MIT license in this repo does **not** cover it. See [`firmware/NOTICE`](firmware/NOTICE) for details.

## Raw evidence
The `reference/` directory contains unedited dumps taken from the device (`system-info.txt`, `root-info.txt`, `01-input-devices.txt`, `04-dmesg-silead.txt`, `corners-evt.txt`, ...).
