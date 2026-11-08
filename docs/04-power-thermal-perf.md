# 04 - Power, memory and performance

With only 1 GB of RAM (882 MB usable) and a slow eMMC, most of the tuning is
about not wasting memory and reducing disk writes. This is the full list of the
changes applied to the base install.

## zram swap (the big one)

The eMMC swap partition (`mmcblk1p3`, 945 MB) is slow and wears the flash.
A **zram** swap device is used instead, with higher priority so it is preferred:

[`config/etc/default/zramswap`](../config/etc/default/zramswap)

- `ALGO=lz4` - fastest compression (least CPU on a weak Atom).
- `PERCENT=100` - use up to the size of RAM for the compressed device.
- `PRIORITY=100` - above the disk swap, so zram is used first.

Enable with `zram-tools`; the `zramswap.service` is enabled. At runtime
(`reference/system-info.txt`):

## Virtual memory sysctls

[`config/etc/sysctl.d/99-zram.conf`](../config/etc/sysctl.d/99-zram.conf)

- `swappiness=100` - with a fast compressed swap, swap aggressively.
- `page-cluster=0` - read one page at a time (good for zram, avoids
  read-ahead waste).
- `vfs_cache_pressure=50` - keep dentries/inodes cached (memory is scarce but
  caching helps on slow flash).
- lower dirty ratios - flush writes sooner in smaller batches, smoother on
  eMMC.

## log2ram + smaller journald

`/var/log` is moved to RAM by **Log2Ram** so logs do not cause constant eMMC
writes:

[`config/etc/log2ram.conf`](../config/etc/log2ram.conf)

`48M` is enough for this system's logs and is synced back to disk periodically
(`log2ram-daily.timer`). journald is capped well below that so it never fills
the RAM log:

[`config/etc/systemd/journald.conf.d/10-size.conf`](../config/etc/systemd/journald.conf.d/10-size.conf)

With `JOURNALD_AWARE=true`, Log2Ram rotates journald before syncing. At runtime
`/var/log` shows as a 48M `log2ram` mount (see `reference/system-info.txt`).

## Kernel command line

[`config/etc/default/grub`](../config/etc/default/grub)

- `mitigations=off` - this CPU is vulnerable to Spectre/Meltdown but the
  mitigations cost measurable performance on an Atom; this is a deliberate
  trade-off for a personal, non-adversarial device.
- `nowatchdog` - disable the hardware watchdog (saves power, no watchdog needed).
- `quiet` + `GRUB_TIMEOUT=1` - faster, quieter boot.

Apply with `sudo update-grub` and reboot.

> Note: `mitigations=off` triggers the kernel's "vulnerable" warnings - expected
> and intentional here. If you care about those CVEs, drop the flag.

## Modules

Unused virtualisation support is blacklisted to save memory:

[`config/etc/modprobe.d/blacklist-unused.conf`](../config/etc/modprobe.d/blacklist-unused.conf)

## Services and targets

- Default systemd target set to `multi-user.target` (no graphical/display
  manager target). Starting a graphical session is outside this repo.
- `networking.service` (ifupdown) is **disabled**; networking is handled by
  **NetworkManager**.
- `fstrim.timer` and `dpkg-db-backup.timer` are enabled (periodic trim is good
  for eMMC).
- `lm-sensors` is enabled for temperature readout.

Enabled units on the device (`reference/system-info.txt`): apparmor, bluetooth,
console-setup, getty@, keyboard-setup, lm-sensors, log2ram, NetworkManager
(+dispatcher), ssh, systemd-pstore, systemd-timesyncd, wpa_supplicant,
zerotier-one, zramswap, remote-fs.target, plus the fstrim/log2ram/backup/logrotate
timers.
