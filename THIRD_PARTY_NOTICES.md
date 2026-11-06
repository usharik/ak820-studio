# Third-party notices

AK820 Studio is an independent implementation; no source code was copied from the projects below.
The protocol knowledge and the key layout data come from them.

## AK820 Center — key layout data and protocol description

`Sources/AK820Kit/Layout.swift` was generated from `resources/rgb-keyboard.xml` of
[Twyx22/ak820-center](https://github.com/Twyx22/ak820-center) (itself taken from the vendor's
official Windows driver). Protocol details follow its `PROTOCOL.md`.

```
MIT License

Copyright (c) 2026 AK820 Center contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## ak820-mac — hardware-verified packet formats on macOS

Packet sequences, checksums, macro block layout, system settings packet and the
"static = breathing at speed 0" behaviour follow
[gha-projects/ak820-mac](https://github.com/gha-projects/ak820-mac) (`ak820.py`, `docs/`),
MIT License, Copyright (c) 2026 gha.

The 2.4 GHz receiver framing (`docs/receptor-24g.md`) and the system-audio spectrum analyzer
(`musica/espectro.swift`, ported to `Sources/AK820Studio/Live.swift`) also come from ak820-mac.
