# 05 - Troubleshooting

Known issues hit while building this setup, and how they were resolved.

## Touchscreen

**Detected but touches land on the wrong place / wrong axis.** The digitizer is
transposed; the libinput calibration matrix is missing or wrong:

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input --action=change
```

See [docs/02-touchscreen-silead.md](02-touchscreen-silead.md#calibration).

## Input

**Power button does nothing.** `powerkeyd` reads `axp20x-pek` directly and the
user must be in the `input` group. Check `groups` and `/tmp/powerkeyd.log`.

## Kernel

**Touchscreen disappears on a newer kernel.** Debian 12's stock **6.1** kernel
enumerates the Silead digitizer as an ACPI I2C client:

```
silead_ts i2c-MSSL1680:00: firmware: direct-loading firmware silead/mssl1680.fw
input: silead_ts as /devices/platform/80860F41:03/i2c-3/i2c-MSSL1680:00/input/input5
```

On **6.12** the ACPI device is still there (`MSSL1680:00`, path
`\_SB_.I2C4.TCS0`, address `0x40` on `80860F41:03` / `i2c-3`), but **no I2C
client is created**, so the driver never binds:

- the `silead` module loads, but there is no `i2c-MSSL1680:00` device and no
  `physical_node`;
- `modprobe` of a manual client at `0x40` creates `i2c-3-0040`, but the driver
  refuses to bind and a manual bind returns rc=1 - the ACPI companion
  properties are missing;
- `acpi_osi=Linux` and `acpi_osi=! acpi_osi=Windows 2013` do **not** help.

**Recommendation: stay on the 6.1 kernel.**

## Audio

**No sound.** Ensure `firmware-intel-sound` is installed (SST firmware) and the
`bytcr-rt5640` card is present (`aplay -l`). Use `alsamixer` or your preferred
sound server/mixer to unmute and set the level.
