# 08 - Vulkan renderer backport (wlroots 0.16.2 + sway 1.8.1)

## Why

The distro sway on bookworm is **1.7** with **wlroots 0.15.1**, which has only a
GLES2 renderer. wlroots gained a **Vulkan renderer in 0.16**, and the Intel Bay
Trail GPU (Gen7, driver `hasvk`) can use it. This is a build-from-source
backport: it is optional, and the desktop falls back to the distro sway
automatically if it fails.

The goal is *slightly lower idle CPU / better compositing behaviour* on the very
weak GPU, not gaming performance. Measured in a nested headless run
(`es2gears`, 10 s):

| Renderer | CPU | Memory |
|---|---|---|
| Vulkan | ~3% | ~82.6 MB |
| GLES2 | ~8% | ~84.8 MB |

Idle Vulkan usage is ~0.8%.

> Caveat: Bay Trail Vulkan is **incomplete**; Mesa prints
> `MESA-INTEL: warning: Bay Trail Vulkan support is incomplete`. And crucially,
> **screen capture (`grim`) does not work under the Vulkan renderer** - use
> GLES2 for screenshots. See [docs/07-troubleshooting.md](07-troubleshooting.md).

## Prerequisites

Build tools and dev headers (many already present because Mesa 25 from
bookworm-backports is used):

```sh
sudo apt install -y build-essential git meson ninja-build pkg-config scdoc \
  libwayland-dev wayland-protocols libdrm-dev libgbm-dev \
  libxkbcommon-dev libinput-dev libseat-dev libpixman-1-dev \
  libcap-dev libpcre2-dev libjson-c-dev libgdk-pixbuf-2.0-dev \
  libcairo2-dev libpango1.0-dev \
  libvulkan-dev mesa-vulkan-drivers vulkan-tools \
  libxcb-util-dev libxcb-errors-dev libxcb-render-util0-dev \
  libxcb-icccm4-dev libxcb-image0-dev xwayland
```

`wayland-protocols` must be >= 1.31 (bookworm is fine). If a dependency is too
old, enable `bookworm-backports` (already in `config/etc/apt/sources.list`).

## Build wlroots 0.16.2

```sh
mkdir -p ~/build && cd ~/build
git clone -b 0.16.2 https://gitlab.freedesktop.org/wlroots/wlroots.git
cd wlroots

# Optional patch: default the Vulkan renderer's verbose debug output off,
# to reduce noise/overhead on a weak GPU (file: render/vulkan/renderer.c).
sed -i 's/default_debug = true/default_debug = false/' render/vulkan/renderer.c

meson setup build \
  --prefix=/usr/local \
  -Drenderers=gles2,vulkan \
  -Dexamples=false
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

This installs to `/usr/local` (e.g. `/usr/local/lib/libwlroots.so.11`), leaving
the distro `libwlroots10` untouched.

## Build sway 1.8.1

sway 1.8.1 links against wlroots 0.16:

```sh
cd ~/build
git clone -b 1.8.1 https://github.com/swaywm/sway.git
cd sway
meson setup build --prefix=/usr/local
ninja -C build
sudo ninja -C build install
sudo ldconfig
```

`/usr/local/bin/sway` now exists and will be found before the distro
`/usr/bin/sway`.

## Use it

`~/.bash_profile` ([sway-tablet/docs/01-desktop-sway.md](https://github.com/cicag/sway-tablet/blob/main/docs/01-desktop-sway.md)) already tries
`/usr/local/bin/sway` with `WLR_RENDERER=vulkan` and falls back to gles2:

```sh
export WLR_RENDERER=vulkan
/usr/local/bin/sway && exit 0
export WLR_RENDERER=gles2
exec sway
```

To force GLES2 in one session: `WLR_RENDERER=gles2 sway`.

## Verify

```sh
sway --version                    # -> sway version 1.8.1
vulkaninfo | grep deviceName      # -> Intel(R) HD Graphics (BYT), Mesa 25.x
```

Vulkan ICDs are the standard ones in `/usr/share/vulkan/icd.d/`
(`intel_hasvk_icd.json` is the one used for BYT).

## Uninstall / revert

```sh
cd ~/build/wlroots && sudo ninja -C build uninstall
cd ~/build/sway    && sudo ninja -C build uninstall
sudo ldconfig
```

Then remove the `WLR_RENDERER=vulkan` block from `~/.bash_profile` to always use
the distro sway.

## Reference

The Vulkan renderer entry point that matters for the read-pixels failure is
`render/vulkan/renderer.c` in wlroots (the patch above touches the same file).
The backport exists only because bookworm's wlroots (0.15.1) predates the Vulkan
renderer.
