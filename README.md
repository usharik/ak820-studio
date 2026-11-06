# AK820 Studio

**Native macOS configurator for the AJAZZ AK820 Pro keyboard** — no Windows, no browser.

[Русская версия](README.ru.md)

The vendor's configuration software exists only for Windows (plus a very limited web app).
AK820 Studio does the same job natively on macOS, talking to the keyboard over USB HID.

![Lighting](docs/screenshots/lighting.png)

## Keyboard

AJAZZ AK820 Pro — 75 % gasket-mount mechanical keyboard, 81 keys, knob, 0.85″ TFT screen,
tri-mode (USB-C / 2.4 GHz / Bluetooth). Also sold as EPOMAKER × AJAZZ and ATTACK SHARK × AJAZZ.

- AJAZZ official store: <https://ajazzstore.com/products/ajazz-ak820-pro>
- AJAZZ official website (drivers, manuals): <https://www.a-jazz.com/en/search.jsp?id=422&q=ak820>
- EPOMAKER: <https://epomaker.com/products/ajazz-ak820-pro>
- ATTACK SHARK: <https://attackshark.com/products/attackshark-ajazz-ak820-pro-75-mechanical-keyboard>
- User manual: <https://manuals.plus/asin/B0CMWKN55N>

Supported USB IDs: VID `0C45` (SONiX), PID `8009` / `800A` (wired).

## Features

| Tab | What it does |
|---|---|
| Lighting | 19 built-in effects, color or rainbow, brightness, speed, direction; applied instantly |
| Key Colors | per-key RGB painted on a drawing of the keyboard, presets |
| Keys | remap keys on the base and Fn layers: key / shortcut, media, mouse, macro, disable; "press to pick" |
| Macros | text, key combinations, pauses, mouse clicks; once / N times / toggle / while held / step |
| Screen | image or GIF (up to 140 frames) for the 128×128 screen with animated preview; clock sync |
| Settings | sleep timer, Fn mode, debounce, Win / Alt+Tab / Alt+F4 locks, language, export / import |
| Menu bar | quick effects, colors, brightness, clock sync, launch at login |

Everything is stored **in the keyboard** and keeps working on any computer and any connection.
Configuration works **over the USB-C cable only** (same as the official software).

| Keys | Key colors | Menu bar |
|---|---|---|
| ![Keys](docs/screenshots/keys.png) | ![Key colors](docs/screenshots/key-colors.png) | ![Menu bar](docs/screenshots/menu-bar.png) |

Languages: English, Russian. Adding a language is one file — see [TRANSLATING.md](TRANSLATING.md).

## Build and install

Requires macOS 14+ and Xcode (SwiftUI macros need the full Xcode toolchain, Command Line Tools are not enough).

```sh
git clone https://github.com/usharik/ak820-studio.git
cd ak820-studio
./scripts/build-app.sh
cp -R "dist/AK820 Studio.app" /Applications/
```

The app is ad-hoc signed. If macOS refuses to open it: right-click → Open.

Command-line tool: `dist/ak820ctl` (`info`, `battery`, `clock`, `lights`, `image`; `-v` prints the packets).

## How it works

- `Sources/AK820Kit` — the protocol: IOKit HID, 64-byte feature reports on the vendor interface
  `0xFF13`, screen data in 4096-byte output reports on `0xFF68`.
- `Sources/AK820Studio` — SwiftUI app. The keyboard can't report its settings back, so the last
  written state is kept in `~/Library/Application Support/AK820Studio/config.json`.
- `Sources/ak820ctl` — CLI.
- `Localization/*.lproj` — translations.

## Status

Verified on a real AK820 Pro (PID `8009`): detection, battery level, clock sync.
The other features follow packet formats that were verified on this keyboard model by the projects
below, but have had little testing in this app yet. If something doesn't work, open
**Settings → Keyboard communication log** and file an issue with its contents.

To restore the factory keymap: **Keys → Reset all → Write to keyboard**.

Not supported yet: configuration over 2.4 GHz / Bluetooth, audio-reactive lighting.

## Credits and materials used

The protocol was reverse-engineered by the community from the official Windows driver
(`DeviceDriver.exe` v1.0.0.5). AK820 Studio is a new implementation built on that work:

- [gha-projects/ak820-mac](https://github.com/gha-projects/ak820-mac) — macOS tool for the AK820 Pro;
  hardware-verified packet sequences, checksums, macro format, settings packet (main reference).
- [Twyx22/ak820-center](https://github.com/Twyx22/ak820-center) — Linux app; `PROTOCOL.md` and the
  official key layout (`rgb-keyboard.xml`) from which the key map here was generated.
- [wsclx/ak820pro-modder](https://github.com/wsclx/ak820pro-modder) and
  [adamauthor/ak820pro-modder](https://github.com/adamauthor/ak820pro-modder) — protocol research on both firmware families.
- [igordev96/AJAZZ-AK820-Pro-Driver](https://github.com/igordev96/AJAZZ-AK820-Pro-Driver) — WebHID configurator.
- [hcristosm/ak820-linux](https://github.com/hcristosm/ak820-linux) — Linux tool (RGB, screen, clock).

Earlier community work these projects build on:
[gohv/EPOMAKER-Ajazz-AK820-Pro](https://github.com/gohv/EPOMAKER-Ajazz-AK820-Pro),
[TaxMachine/ajazz-keyboard-software-linux](https://github.com/TaxMachine/ajazz-keyboard-software-linux),
[KyleBoyer/TFTTimeSync-node](https://github.com/KyleBoyer/TFTTimeSync-node),
[Aiacos/ajazz-control-center](https://github.com/Aiacos/ajazz-control-center),
[gusleig/ajazz-ak820-pro-mac](https://github.com/gusleig/ajazz-ak820-pro-mac),
[MemerGamer/AjazzAk820ProUnofficialWebdriver](https://github.com/MemerGamer/AjazzAk820ProUnofficialWebdriver).

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Unofficial project, not affiliated with AJAZZ or EPOMAKER. Use at your own risk.

## License

MIT — see [LICENSE](LICENSE).
