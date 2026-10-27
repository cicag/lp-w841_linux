# lp-w841_linux

Turning the **Wearness LP-W841** into a usable Linux tablet.
Umm, My device just happened collecting dust since since 2023 because I forgot to dump the Silead touchscreen firmware from the original Windows installation. Fortunately, someone did it, a compatible firmware was eventually found
in [onitake/gsl-firmware](https://github.com/onitake/gsl-firmware/tree/master/firmware/mytab/Garda_U80GT)
(the Garda U80GT entry uses the same hardware); the exact provenance is in
[`firmware/NOTICE`](firmware/NOTICE).

You may want to skip to the [Touchscreen](#touchscreen-mssl1680) part, the other
hardware tweaks are optional.

This repo is the **device-level** half of the setup: how to install Debian on
it and make the hardware work - touchscreen, display, backlight, audio, power, memory tuning and the kernel quirks. It contains the exact
configuration files, the touchscreen firmware, and the documentation with the
collected evidence.

The Silead touchscreen firmware is sourced from
[onitake/gsl-firmware](https://github.com/onitake/gsl-firmware/tree/master/firmware/mytab/Garda_U80GT)
(compatible with Mytab Garda U80GT). Provenance is in [`firmware/NOTICE`](firmware/NOTICE).

## Hardware

| Item | Value |
|---|---|
| Device | Wearness LP-W841 (Bay Trail tablet, Insyde 32-bit UEFI) |
| CPU | Intel Atom Z3735, 4 cores, x86-64 |
| RAM | 1 GB (882 MB usable) |
| Storage | 14.7 GB eMMC (`/dev/mmcblk1`), root on F2FS |
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
- **Debian 12 (bookworm) amd64** with a 32-bit UEFI bootloader and the stock **6.1** kernel ([docs/01-debian-install.md](docs/01-debian-install.md)), or your distro choice.
- Root/sudo access.
- User added to the `video` and `input` groups, this not needed for touchscreen setup, skip to the touchscreen part.

### APT sources and components
- Enable `contrib`, `non-free`, `non-free-firmware`, and **bookworm-backports** ([`config/etc/apt/sources.list`](config/etc/apt/sources.list)).
- Add the azlux repository for `log2ram` ([`config/etc/apt/sources.list.d/azlux.list`](config/etc/apt/sources.list.d/azlux.list)).

### Firmware packages
- `firmware-realtek` (WiFi/BT)
- `firmware-intel-sound` (Intel SST firmware for `bytcr-rt5640`)
- `firmware-linux` / `firmware-misc` (pulled as dependencies as needed)

### Device-level packages
```sh
sudo apt install \
  network-manager bluez alsa-utils \
  libinput-tools evtest mesa-utils vulkan-tools \
  lm-sensors zram-tools log2ram openssh-server
```

### Tools
- `install`, `udevadm`, `modprobe`, `update-initramfs`, `update-grub` (only needed for the tweaks listed below).

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
- Firmware provenance, SHA256/MD5, and upstream commit: [`firmware/NOTICE`](firmware/NOTICE), [`firmware/README.md`](firmware/README.md).
- Calibration details and the matrix rationale: [docs/02-touchscreen-silead.md](docs/02-touchscreen-silead.md).
- **Use the stock Debian 12 6.1 kernel.** On 6.12+ the ACPI I2C client is not created and the touchscreen disappears ([docs/05-troubleshooting.md](docs/05-troubleshooting.md#kernel)).
- Mapping to a specific output/rotation depends on your display server/compositor and is outside this repo. For a minimalist sway setup tuned for this touchscreen, see [`cicag/sway-tablet`](https://github.com/cicag/sway-tablet).

## Tweak list

All changes below are optional and manual. Review and copy only what you need - there is no automatic installer. Files mirror absolute paths under [`config/etc/`](config/etc/).

| Area | Files in `config/etc/` | Quick apply | Doc | Purpose |
|---|---|---|---|---|
| APT repos | `apt/sources.list`, `apt/sources.list.d/azlux.list` | `sudo cp ... /etc/... && sudo apt update` | [docs/01-debian-install.md](docs/01-debian-install.md) | Enable `contrib/non-free/non-free-firmware`, `bookworm-backports`, azlux for `log2ram`. |
| GRUB/kernel cmdline | `default/grub` | `sudo cp config/etc/default/grub /etc/default/grub && sudo update-grub` | [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | `GRUB_TIMEOUT=1`, `mitigations=off nowatchdog` (trade-off), keep stock 6.1. |
| Initramfs modules | `initramfs-tools/modules` | `sudo cp config/etc/initramfs-tools/modules /etc/initramfs-tools/modules && sudo update-initramfs -u` | [docs/01-debian-install.md](docs/01-debian-install.md) | Ensure required modules load at early boot. |
| i915 / GPU | `modprobe.d/i915.conf` | `sudo cp config/etc/modprobe.d/i915.conf /etc/modprobe.d/ && sudo update-initramfs -u` | [docs/03-display-backlight.md](docs/03-display-backlight.md) | `enable_fbc=1 enable_psr=1 fastboot=1`. |
| HDMI audio block | `modprobe.d/50-block-hdmi-audio.conf` | `sudo cp config/etc/modprobe.d/50-block-hdmi-audio.conf /etc/modprobe.d/` | [docs/03-display-backlight.md](docs/03-display-backlight.md) | Avoid unused HDMI audio card conflicts. |
| Blacklist unused | `modprobe.d/blacklist-unused.conf`, `modprobe.d/intel-microcode-blacklist.conf` | `sudo cp config/etc/modprobe.d/*.conf /etc/modprobe.d/` | [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | Save memory / avoid unnecessary modules. |
| Modules load | `modules-load.d/gamepad.conf` | `sudo cp config/etc/modules-load.d/gamepad.conf /etc/modules-load.d/` | [docs/05-troubleshooting.md](docs/05-troubleshooting.md) | Optional: load related input modules. |
| Backlight permissions | `udev/rules.d/90-backlight.rules` | `sudo cp config/etc/udev/rules.d/90-backlight.rules /etc/udev/rules.d/ && sudo udevadm control --reload-rules && sudo udevadm trigger` | [docs/03-display-backlight.md](docs/03-display-backlight.md) | Allow `video` group to write `intel_backlight/brightness`. |
| VA-API env | `environment` | `sudo cp config/etc/environment /etc/environment` | [docs/03-display-backlight.md](docs/03-display-backlight.md) | `LIBVA_DRIVER_NAME=i965`. |
| zram swap | `default/zramswap`, `sysctl.d/99-zram.conf` | `sudo cp config/etc/default/zramswap /etc/default/ && sudo cp config/etc/sysctl.d/99-zram.conf /etc/sysctl.d/ && sudo systemctl enable --now zramswap && sudo sysctl --system` | [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | Prefer zram over slow eMMC swap; aggressive swappiness. |
| log2ram + journald | `log2ram.conf`, `systemd/journald.conf.d/10-size.conf` | `sudo cp config/etc/log2ram.conf /etc/ && sudo cp -r config/etc/systemd/journald.conf.d /etc/systemd/ && sudo systemctl enable --now log2ram` | [docs/04-power-thermal-perf.md](docs/04-power-thermal-perf.md) | Reduce eMMC writes for logs/journald. |

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
