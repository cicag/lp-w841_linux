# 03 - Display, backlight and audio

## Panel

- One output: **DSI-1**, native **800x1280**, portrait.
- Rotation and output mapping are handled by the display server or compositor
  and are outside this repo.

## Backlight

The panel backlight is the standard `intel_backlight` PWM interface:

```
/sys/class/backlight/intel_backlight/{brightness,max_brightness}
```

By default `brightness` is `root:root` mode `0644`, so a normal user cannot
change it. Apply
[`config/etc/udev/rules.d/90-backlight.rules`](../config/etc/udev/rules.d/90-backlight.rules):

```
SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod 664 /sys/class/backlight/%k/brightness"
```

Your user must be in the `video` group. Then any process running as that user can
write the brightness directly; use your preferred brightness tool or the sysfs
file above.

## i915 module options

The GPU options are set in a modprobe file, **not** in the kernel command line
or `/etc/environment`:

[`config/etc/modprobe.d/i915.conf`](../config/etc/modprobe.d/i915.conf)

```
options i915 enable_fbc=1 enable_psr=1 fastboot=1
```

- `enable_fbc=1` - framebuffer compression (saves memory bandwidth/power).
- `enable_psr=1` - panel self refresh (panel power saving).
- `fastboot=1` - skip some modeset delay at boot.

## Video / media environment

`/etc/environment` sets the VA-API driver override:

| Variable | Value | Why |
|---|---|---|
| `LIBVA_DRIVER_NAME` | `i965` | legacy VA-API driver, correct for this Gen7 GPU |

[`config/etc/environment`](../config/etc/environment):

```
LIBVA_DRIVER_NAME=i965
```

## Audio

- Card: **`bytcr-rt5640`** (Realtek ALC5640 codec + Intel SST DSP). Requires the
  Intel SST firmware from `firmware-intel-sound` (`fw_sst_0f28.bin`).
- There is also an `Intel HDMI/DP LPE Audio` card (HDMI, unused here).
- Volume/mute handling is outside this repo; use `alsamixer` or your preferred
  sound server/mixer. The hardware volume keys are ordinary evdev key events and
  can be bound by whatever session you use.
- Use [this](https://gist.github.com/jfstenuit/09feac5ab0bff500db81ac9a56a48773) as reference.
