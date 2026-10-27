# Silead touchscreen firmware

`mssl1680.fw` is the firmware for the Silead **MSSL1680** touchscreen used by
the Wearness LP-W841. It must be installed as
`/lib/firmware/silead/mssl1680.fw` for the Linux `silead` driver to load it.

## Source

The file comes from the
[onitake/gsl-firmware](https://github.com/onitake/gsl-firmware/tree/master/firmware/mytab/Garda_U80GT)
project, entry `firmware/mytab/Garda_U80GT/firmware_00.fw`, commit
`dbaac009452f8a4810d02517d5f8e748fefccb2a`.

It is an unmodified byte-for-byte copy of that file, renamed to `mssl1680.fw`
(the name the `silead` driver expects). SHA256:

```
69334fc1a8febbaf74efa92ff870f39ff5f84d7f819993fe35f878ab78c3cfe2
```

## License and attribution

The firmware is proprietary/unknown-licensed third-party material extracted
from a vendor driver. It is **not** covered by this repository's MIT license.
See [`NOTICE`](NOTICE) for the full provenance, compatibility caveat and
disclaimer.

## Install

From the repository root:

```sh
sudo install -Dm644 firmware/mssl1680.fw /lib/firmware/silead/mssl1680.fw
sudo modprobe -r silead && sudo modprobe silead
```

Then check `dmesg | grep -i silead` for
`direct-loading firmware silead/mssl1680.fw`.
