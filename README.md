# plasma-webcam-brightness

Automatic screen brightness for KDE Plasma on machines without an ambient light
sensor. It uses your webcam as the sensor and learns from your manual brightness
changes.

It was written for a desktop with an external monitor controlled over DDC/CI, but
it works with anything Plasma can set the brightness of, laptop backlights
included.

## Why

- Plasma (6.6+) has built-in automatic brightness. It needs a hardware light
  sensor exposed through `iio-sensor-proxy`, and KWin
  [deliberately disables it for DDC/CI monitors](https://invent.kde.org/plasma/kwin/-/blob/master/src/backends/drm/drm_output.cpp).
- [Clight](https://github.com/FedeDP/Clight) uses a webcam, but it drives the
  monitor through its own DDC daemon (`clightd`). That daemon fights KWin and
  PowerDevil for the I²C bus. `clightd` also crashes when it is called during
  startup, and `clight` does not recover from that.
- [wluma](https://github.com/max-baz/wluma) supports a webcam too, but it also
  needs to own the DDC connection itself.

This tool only *reads* the webcam. It sets brightness through Plasma's own
`org.kde.ScreenBrightness` D-Bus API, so:

- KWin/PowerDevil remain the only thing talking to the monitor.
- The brightness keys, OSD, tray slider and idle dimming work as usual.
- If the daemon stops, all you lose is the automatic adjustment.

## How it works

- Every `interval` seconds (default 300) it grabs a single low-res frame at a
  fixed exposure. It adjusts the exposure if the frame is under- or over-exposed.
  Then it computes an ambient level `log2(mean luma / exposure)` in relative
  EV units, and restores the camera's own settings.
- A per-monitor curve maps that level to brightness. Plasma is only asked to
  change brightness when the difference is at least `min_step`. The change
  doesn't show an OSD popup.
- When *you* change brightness (keys, slider, System Settings), the curve is bent
  so it passes through your choice at the current light level, and stays
  monotonic. It can tell your changes apart from its own by the D-Bus context it
  tags them with. Automatic adjustment then pauses until the light changes by
  more than `deadzone_ev`.
- It skips measuring while the screen is locked or another program is using the
  camera, e.g. during a video call. It measures again shortly after unlock and
  resume.

Learned curves live in `~/.local/state/plasma-webcam-brightness/state.json`.

## Requirements

- KDE Plasma 6 (PowerDevil provides `org.kde.ScreenBrightness`)
- Python 3.11+ with PyGObject (`python-gobject` on Arch)
- `v4l-utils` and `ffmpeg`
- A UVC webcam with manual exposure control. Your user needs access to it,
  which is normally the case for the logged-in seat user.
- For external monitors: DDC/CI enabled on the monitor. The monitor must show
  up in Plasma's brightness settings.

## Install

```sh
make install PREFIX=~/.local          # or: sudo make install
systemctl --user daemon-reload
systemctl --user enable --now plasma-webcam-brightness
```

Run only one automatic-brightness tool at a time. Stop clight, wluma and the
like before enabling this one.

## Usage

```sh
plasma-webcam-brightness measure      # one reading, prints the ambient level
plasma-webcam-brightness status       # displays, current/predicted brightness, curves
plasma-webcam-brightness reset        # forget what it learned
journalctl --user -u plasma-webcam-brightness -f
```

The default curve is only a starting point. Correct it with the brightness keys
a few times, in different lighting, and it adapts.

## Configuration

Optional. Create `~/.config/plasma-webcam-brightness.toml`:

```toml
device = "/dev/v4l/by-id/usb-046d_HD_Pro_Webcam_C920_XXXXXXXX-video-index0"  # default /dev/video0
interval = 300        # seconds between measurements
min_step = 0.04       # smallest change worth making (fraction of full brightness)
deadzone_ev = 0.6     # after a manual change, ignore light changes smaller than this
displays = []         # labels (see `status`) to control; empty = all
```

## Caveats

- The webcam light may blink briefly on every measurement.
- Ambient levels are relative to the particular camera. They are not lux. That's
  fine, because the curve is learned per setup.
- Some monitors dislike frequent DDC/CI writes. The default interval and
  minimum step keep writes rare.

## License

MIT
