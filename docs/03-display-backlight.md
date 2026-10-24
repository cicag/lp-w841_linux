# 03 - Display, backlight and audio

## Panel

- One output: **DSI-1**, native **800x1280**, portrait. The device is held in
  portrait; no default rotation is applied (transform `normal`).
- Compositor: sway. Wallpaper via `swaybg` (see
  [sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)).
- Rotation is manual (`waybar-rotate.sh`, cycles the DSI-1 `transform`).

## Backlight

The panel backlight is the standard `intel_backlight` PWM interface:

```
/sys/class/backlight/intel_backlight/{brightness,max_brightness}
```

By default `brightness` is `root:root` mode `0644`, so a normal user cannot
change it. A udev rule relaxes this at boot -
[`config/etc/udev/rules.d/90-backlight.rules`](../config/etc/udev/rules.d/90-backlight.rules):

```
SUBSYSTEM=="backlight", ACTION=="add", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod 664 /sys/class/backlight/%k/brightness"
```

Your user must be in the `video` group, then the GTK control panel
([`controlpanel`](https://github.com/cicag/sway-tablet/blob/main/config/home/.local/bin/controlpanel)) can write the
brightness directly; it also reads current/max to show a percentage.

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

`/etc/environment` and the sway autostart set a couple of environment variables:

| Variable | Value | Why |
|---|---|---|
| `LIBVA_DRIVER_NAME` | `i965` | legacy VA-API driver, correct for this Gen7 GPU |
| `MOZ_ENABLE_WAYLAND` | `1` | Firefox on Wayland |

[`config/etc/environment`](../config/etc/environment):

```
LIBVA_DRIVER_NAME=i965
```

## Audio

- Card: **`bytcr-rt5640`** (Realtek ALC5640 codec + Intel SST DSP). Requires the
  Intel SST firmware from `firmware-intel-sound` (`fw_sst_0f28.bin`).
- There is also an `Intel HDMI/DP LPE Audio` card (HDMI, unused here).
- Volume/mute are handled by PipeWire/WirePlumber (`wpctl`); the hardware volume
  keys are bound in sway to `wpctl` (see
  [sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)).

```
# sway bindsym
bindsym XF86AudioRaiseVolume exec wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+
bindsym XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindsym XF86AudioMute        exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
```

The control panel also lists output sinks and lets you pick the default
(`wpctl set-default`), which is handy for switching between the speaker and a
Bluetooth headset.

## Known display caveat: screenshots under Vulkan

If the session runs with `WLR_RENDERER=vulkan`, `grim` (and any screen capture)
fails with a wlroots Vulkan read-pixels error. Take screenshots under the
`gles2` renderer instead. See
[docs/07-troubleshooting.md](07-troubleshooting.md).
