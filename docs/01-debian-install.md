# 01 - Debian install

This document records how the base system was set up and the traps specific to
this hardware. It can be done with **Debian 12 (bookworm)** or **Debian 13
(trixie) amd64**.

> **Silead touchscreen requirement:** use/pin **kernel 6.1**. Debian 12 ships
> 6.1. Debian 13 is OK as long as you downgrade/pin the kernel to 6.1; on 6.12+
> the Silead ACPI I2C client is not created and the touchscreen does not work.

## The 32-bit UEFI

Baytrail tablets generally ship a **32-bit UEFI** even though their CPU is
64-bit. Fortunately, the Debian *amd64* installer contains a 32-bit EFI loader too.

## Partitioning

The resulting layout (`lsblk`, see `reference/system-info.txt`) is:

| Device | Size | FS | Mount |
|---|---|---|---|
| mmcblk1p1 | 512M | vfat | `/boot/efi` |
| mmcblk1p2 | 488M | ext4 | `/boot` |
| mmcblk1p3 | 945M | swap | (swap) |
| mmcblk1p4 | ~13G | **f2fs** | `/` |

F2FS is chosen for the root filesystem because it is flash-friendly and its
read/write behaviour suits eMMC. `/etc/fstab` is machine-specific (its UUIDs
come from your own partitions), so it is not shipped - adapt
[`reference/fstab.example`](../reference/fstab.example) if you need the same
layout.

## Firmware packages

The install must have `contrib`, `non-free`, and `non-free-firmware` enabled
for your Debian release. The example [`config/etc/apt/sources.list`](../config/etc/apt/sources.list)
in this repo is from a **bookworm** setup (including `bookworm-backports`);
adapt it to your release if you use Debian 13/trixie or a different mirror
layout. The relevant binary firmware blobs come from:

- `firmware-realtek` - WiFi + Bluetooth for the **RTL8723BS**.
- `firmware-intel-sound` - the **Intel SST** firmware (`fw_sst_0f28.bin`)
  needed by `bytcr-rt5640` audio.
- `firmware-linux` / `firmware-misc` as pulled in as dependencies.

> The **touchscreen** firmware is *not* in any package - see
> [docs/02-touchscreen-silead.md](02-touchscreen-silead.md). It has to be
> copied from an extracted Windows driver.

## Device packages

Beyond the standard system, install the device-level packages for your Debian
release (some setups use backports for newer Mesa/GPU packages; the shipped
example sources include bookworm-backports). The graphical session and desktop
stack are out of scope - install your preferred one separately:

```sh
sudo apt install \
  network-manager \
  bluez \
  alsa-utils \
  libinput-tools evtest \
  mesa-utils vulkan-tools \
  lm-sensors \
  zram-tools log2ram \
  openssh-server
```

Key device-level package versions observed on the device (`apt policy`, see
`reference/system-info.txt`):

```
mesa 25.0.7-2~bpo12+1
libinput 1.22.1
log2ram 1.7.2, zram-tools 0.3.3.1
```

## Users

- Create your own user during installation; the rest of the docs assume it is
  `$USER`. Add it to the `video` and `input` groups.
- The base system boots to `multi-user.target`. Starting a graphical session
  (display manager, autologin, compositor, desktop) is outside this repo.

## Optional: keep the system lean

After installation the following were applied (details in
[docs/04-power-thermal-perf.md](04-power-thermal-perf.md)):

- swap removed from the default target path in favour of zram,
- `log2ram` for `/var/log`, smaller journald,
- trimming of unused services (`multi-user.target`, disable `networking`),
- kernel cmdline `mitigations=off nowatchdog`.
