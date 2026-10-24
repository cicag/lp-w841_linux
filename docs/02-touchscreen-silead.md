# 02 - Silead touchscreen (MSSL1680)

This is the most hardware-specific part of the setup. The touchscreen works
out of the box **only after** a device-specific firmware blob is placed in
`/lib/firmware/silead/` and a calibration matrix is installed. A fresh Debian
install does **not** touchscreen-anything: see the
[Debian 13 anomaly](#debian-13-anomaly-touchscreen-not-detected) at the bottom.

## Identity

- Controller: **Silead MSSL1680**, on I2C bus 3, ACPI node `MSSL1680`,
  platform device `80860F41:03`.
- Kernel driver: `silead` (mainline, module).
- Input device name: **`silead_ts`**, `PROP=2` (`INPUT_PROP_DIRECT`),
  node `/dev/input/eventX` (event number is not stable).

```
$ dmesg | grep -i silead
silead_ts i2c-MSSL1680:00: supply vddio not found, using dummy regulator
silead_ts i2c-MSSL1680:00: supply avdd not found, using dummy regulator
silead_ts i2c-MSSL1680:00: Silead chip ID: 0x80360000
silead_ts i2c-MSSL1680:00: firmware: direct-loading firmware silead/mssl1680.fw
input: silead_ts as /devices/platform/80860F41:03/i2c-3/i2c-MSSL1680:00/input/input1
```

`0x80360000` is the chip ID reported by this exact panel.

## Firmware

The driver asks the kernel for `silead/mssl1680.fw` and **only registers the
input device after that firmware has been loaded successfully**. There is no
fallback: without the file, the probe aborts and `silead_ts` never appears.

| | |
|---|---|
| Path | `/lib/firmware/silead/mssl1680.fw` |
| Size | 35376 bytes |
| MD5 | `aa4340ace4dbf14e8a375b0afad382d7` |

A copy is kept in this repo at
[`firmware/mssl1680.fw`](../firmware/mssl1680.fw) and is installed by
[`install.sh`](../install.sh).

### Where it comes from

The blob is proprietary and is **not shipped by any Debian package** (verified:
`dpkg -S /lib/firmware/silead/mssl1680.fw` -> *no path found*; it is not owned by
`firmware-*`). It originates from the tablet's **Windows Silead/Goodix driver**
and is extracted with the tools in
[onitake/gsl-firmware](https://github.com/onitake/gsl-firmware)
(`fwtool` / `silead_scrub`). For this panel the extracted file is exactly
`mssl1680.fw`.

### Install

```sh
sudo install -d /lib/firmware/silead
sudo cp mssl1680.fw /lib/firmware/silead/mssl1680.fw
# reload the driver (or just reboot)
sudo modprobe -r silead && sudo modprobe silead
```

### Verify

```sh
dmesg | grep -i silead            # expect "direct-loading firmware silead/mssl1680.fw"
libinput list-devices | grep -A5 -i silead   # expect a silead_ts device
ls /lib/firmware/silead/
```

If `direct-loading` is absent, or dmesg reports a firmware load failure, the
file is missing/misnamed or the path is wrong. `modinfo silead | grep firmware`
shows the exact filename the driver expects.

## Calibration

Even with the firmware loaded the digitizer is **transposed and offset**
relative to the screen, so a raw touch does not land where you press. This is
fixed with a **libinput calibration matrix**.

### What the hardware reports

- All axes (`ABS_X`, `ABS_Y`, `ABS_MT_POSITION_X/Y`) report `0..4095`.
- The *real* digitizer range is much smaller:
  - raw X: `0..1654`
  - raw Y: `0..895`
- The axes are **swapped**: `screenX ~ rawY`, `screenY ~ rawX`.
  (Raw capture is in [`reference/raw-capture.txt`](../reference/raw-capture.txt).)

### Deriving the matrix

Four corner taps were recorded (raw `x,y`) and mapped to the four screen corners
(log in [`reference/corners-evt.txt`](../reference/corners-evt.txt)):

```
TL (32, 13)     TR (28, 884)
BL (1636, 14)   BR (1641, 883)
```

Note how the raw `x` barely changes between T and B (32 -> 1636 is the vertical
screen direction) while raw `y` sweeps the horizontal - confirming the
transpose. Fitting an affine transform from these points yields the 6-value
libinput matrix:

```
0.000008 4.706890 -0.015518 2.545830 -0.001448 -0.018488
```

libinput interprets the 6 numbers as the first two rows of a 3x3 matrix
`[a b c / d e f / 0 0 1]`, applied to normalized touch coordinates. Here `b`
(~4.7) maps raw Y to screen X and `d` (~2.55) maps raw X to screen Y; `c`/`f`
are the small offsets, `a`/`e` are ~0.

### Apply it (persistent)

Installed as a udev rule so libinput picks it up when the device appears -
[`config/etc/udev/rules.d/99-silead-calibration.rules`](../config/etc/udev/rules.d/99-silead-calibration.rules):

```
# Silead MSSL1680 (silead_ts) touchscreen calibration for DSI-1 800x1280 (portrait).
# Digitizer is transposed: screenX ~ rawY, screenY ~ rawX. Fitted from 4-corner taps.
SUBSYSTEM=="input", ATTRS{name}=="silead_ts", ENV{LIBINPUT_CALIBRATION_MATRIX}="0.000008 4.706890 -0.015518 2.545830 -0.001448 -0.018488"
```

Reload without rebooting:

```sh
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input --action=change
```

> The values above were fitted on the author's unit. If touches are slightly
> off on another LP-E841, repeat the four-corner capture and re-fit - the
> procedure is fully described above.
>
> The **udev** property takes **6** floats. The equivalent **Xorg/libinput X
> property** takes **9** (a full 3x3, ending `0 0 1`). This matters only if you
> are on Xorg; sway/Wayland reads the udev property.

### Live test / temporary apply

On Wayland the calibration can be checked by looking at where a drag lands; on
Xorg you can apply it interactively:

```sh
xinput set-prop silead_ts "libinput Calibration Matrix" \
  0.000008 4.706890 -0.015518 2.545830 -0.001448 -0.018488 0 0 1
```

If a corner is consistently off, re-tap the 4 corners and refit; the matrix is
just the affine solution of the 4 point correspondences.

### Map to the panel

The touchscreen itself has no notion of which output it belongs to; sway maps it
in `~/.config/sway/local.conf` (included by `sway/config`, since the device name
is machine-specific — see
[the desktop docs](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)):

```
input "0:0:silead_ts" {
    map_to_output DSI-1
}
```

This is essential because there is exactly one output and the touchscreen would
otherwise be unassigned. Rotation is handled separately
([sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)); note that a display `transform`
change requires judging whether the calibration matrix should also be swapped
for that orientation.

## Two-finger scrolling

The MSSL1680 driver exposes multitouch (`ABS_MT_*`) but sway's default
pointer/scroll handling is awkward with a `DIRECT` touchscreen. A small helper,
`scrollbridge` (kept at
[`scrollbridge`](https://github.com/cicag/sway-tablet/blob/main/config/home/.local/bin/scrollbridge)),
reads the touch events and synthesises scroll on a virtual `uinput` device. It
needs write access to `/dev/uinput`, granted by
[`config/etc/udev/rules.d/99-uinput.rules`](../config/etc/udev/rules.d/99-uinput.rules):

```
KERNEL=="uinput", SUBSYSTEM=="misc", MODE="0660", GROUP="input"
```

It is launched from the sway autostart (see
[sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)). The helper is a prebuilt binary;
no source is included in this repo.

## Quick diagnostic checklist

```sh
dmesg | grep -i silead                  # chip id + firmware load
libinput list-devices | grep -i silead  # is silead_ts present?
sudo evtest /dev/input/eventN           # do raw events arrive?
```

- No `silead_ts` device at all -> firmware missing (next section) or i2c issue.
- `silead_ts` present but touches land off/wrong axis -> calibration matrix.
- Touches work but no scroll -> `scrollbridge` / `/dev/uinput` permissions.

---

## Debian 13 anomaly: touchscreen not detected

Well, somehow when I try it on debian 13 installation, with its 6.18 kernel, the silead firmware didnt load, the driver didnt even appear in the i2c devices list. So, I have debian 12 and 6.1 kernel in this one.
