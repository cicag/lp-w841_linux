# 09 - Troubleshooting

Known issues hit while building this setup, and how they were resolved.

## Touchscreen

**Detected but touches land on the wrong place / wrong axis.** The digitizer is
transposed; the libinput calibration matrix is missing or wrong:

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input --action=change
```

See [docs/02-touchscreen-silead.md](02-touchscreen-silead.md#calibration).

**No two-finger scroll.** `scrollbridge` is not running or cannot open
`/dev/uinput`. Ensure the `99-uinput.rules` udev rule is installed and the
service/launch happened (`pgrep scrollbridge`).

## Display / compositor

**`grim` fails under Vulkan.**

```
[wlr] [render/vulkan/renderer.c:1079] vulkan_read_pixels: could not find adequate memory type for image dump
failed to copy output DSI-1
```

This is the wlroots Vulkan renderer being unable to read pixels back on this
GPU. **Take screenshots with the GLES2 renderer** (`WLR_RENDERER=gles2 sway`).
The screenshots in
[`sway-tablet/screenshots`](https://github.com/cicag/sway-tablet/blob/main/screenshots)
were captured this way.

**`MESA-INTEL: warning: Bay Trail Vulkan support is incomplete`.** Expected -
BYT has incomplete Vulkan. Harmless for the compositor, but prefer OpenGL for
games and other GPU-heavy applications.

**Vulkan validation / obsolete ICD messages.** Cosmetic; the `intel_hasvk` ICD
is the active one for BYT.

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

## Memory / performance

**No sound.** Ensure `firmware-intel-sound` is installed (SST firmware) and the
`bytcr-rt5640` card is up (`wpctl status`).

**SSH session can't find the Wayland session.** Export the session variables:

```sh
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export WAYLAND_DISPLAY=wayland-1
export SWAYSOCK=$(ls -t /run/user/$(id -u)/sway-ipc.*.sock | head -1)
```
