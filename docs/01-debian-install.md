# 01 - Debian install

The tablet runs **Debian 12 (bookworm) amd64**. This document records how the
base system was set up and the traps specific to this hardware.

## The 32-bit UEFI trap

Baytrail tablets generally ship a **32-bit UEFI** even though their CPU is
64-bit. The Debian *amd64* installer contains a 64-bit EFI loader which the
firmware will not boot. To install amd64 you must supply a 32-bit EFI boot
loader on the install media:

1. Write the Debian amd64 `netinst` ISO to a USB stick
   (`dd if=debian-12.*-amd64-netinst.iso of=/dev/sdX bs=4M`).
2. Mount the first (EFI) partition of the stick and add
   `/efi/boot/bootia32.efi` (e.g. copied from the `grub-efi-ia32-bin`
   package / the `bootia32.efi` shipped by many distros), so the firmware can
   find a 32-bit loader.
3. Boot the stick, choosing the EFI entry. From there the normal amd64
   installer runs.

> If the firmware has no boot menu, the tablet's volume/power button combos or
> `efibootmgr` from an existing system can be used to add a boot entry.

## Partitioning

The resulting layout (`lsblk`, see `reference/system-info.txt`) is:

| Device | Size | FS | Mount |
|---|---|---|---|
| mmcblk1p1 | 512M | vfat | `/boot/efi` |
| mmcblk1p2 | 488M | ext4 | `/boot` |
| mmcblk1p3 | 945M | swap | (swap) |
| mmcblk1p4 | ~13G | **f2fs** | `/` |

F2FS is chosen for the root filesystem because it is flash-friendly and its
read/write behaviour suits eMMC. The matching `/etc/fstab` is in
`config/etc/fstab`, and uses UUIDs.

## Firmware packages

The install must have `contrib non-free non-free-firmware` enabled
(`config/etc/apt/sources.list` includes them, plus `bookworm-backports`). The
relevant binary firmware blobs come from:

- `firmware-realtek` - WiFi + Bluetooth for the **RTL8723BS**.
- `firmware-intel-sound` - the **Intel SST** firmware (`fw_sst_0f28.bin`)
  needed by `bytcr-rt5640` audio.
- `firmware-linux` / `firmware-misc` as pulled in as dependencies.

> The **touchscreen** firmware is *not* in any package - see
> [docs/02-touchscreen-silead.md](02-touchscreen-silead.md). It has to be
> copied from an extracted Windows driver.

## Base packages

Beyond the standard system, the desktop stack is installed from the archive
(bookworm) with some pieces from **bookworm-backports** (notably Mesa 25.x,
which is required for the newer wlroots/sway - see
[docs/06-vulkan-renderer-backport.md](06-vulkan-renderer-backport.md)):

```sh
sudo apt install \
  sway swaybg sway-backgrounds waybar wvkbd grim \
  alacritty foot \
  seatd \
  network-manager \
  bluez \
  alsa-utils pipewire wireplumber \
  libinput-tools evtest \
  mesa-utils vulkan-tools \
  python3-gi gir1.2-gtk-3.0 \
  lm-sensors \
  zram-tools log2ram \
  openssh-server
```

Key package versions observed on the device (`apt policy`, see
`reference/system-info.txt`):

```
sway 1.7-6 (stock) ... but /usr/local/bin/sway is 1.8.1 (built, see
[docs/06-vulkan-renderer-backport.md](06-vulkan-renderer-backport.md))
libwlroots10 0.15.1-6, /usr/local/lib/libwlroots.so.11 = 0.16.2
mesa 25.0.7-2~bpo12+1
libinput 1.22.1
waybar 0.9.17-2, wvkbd 0.12-1, grim, log2ram 1.7.2, zram-tools 0.3.3.1
```

## Users, sudo, session

- Create your own user during installation; the commands below assume it is
  `$USER`. `seatd` and `ssh` are enabled.
- The user must be able to run the few root helpers (e.g. `scrollbridge`)
  without an interactive prompt: `autostart.sh` starts it with `sudo -n`, so
  either add a `NOPASSWD` sudoers rule for that binary or run it another way.
- The machine boots to `multi-user.target`, then getty autologin on tty1 starts
  sway (no display manager). See [sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md).
- `/etc/fstab` is machine-specific (its UUIDs come from your own partitions),
  so it is not shipped - adapt [reference/fstab.example](../reference/fstab.example)
  if you need the same f2fs/`/boot`/ESP/swap layout.

## Optional: keep the system lean

After installation the following were applied (details in
[docs/04-power-thermal-perf.md](04-power-thermal-perf.md)):

- swap removed from the default target path in favour of zram,
- `log2ram` for `/var/log`, smaller journald,
- trimming of unused services (`multi-user.target`, disable `networking`),
- kernel cmdline `mitigations=off nowatchdog`.
