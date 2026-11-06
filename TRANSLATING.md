# Translating AK820 Studio

English is the development language: the English strings in the Swift code are the
localization keys. Every other language lives in `Localization/<code>.lproj/Localizable.strings`.

## Add a language

1. Copy `Localization/ru.lproj` to `Localization/<code>.lproj` (for example `de.lproj`).
2. Translate the **right-hand** side of every line and keep the left side unchanged:
   ```
   "Write to keyboard" = "In die Tastatur schreiben";
   ```
   Keep format specifiers: `%lld` (number), `%@` (text), `%%` (a literal percent sign).
3. Run `./scripts/build-app.sh`. The build script picks up every `*.lproj` folder automatically
   and lists it in `Info.plist`; the language appears in **Settings → Language**.

macOS can also switch the language per app: System Settings → General → Language & Region → Applications.

## Add or change a string in code

- SwiftUI literals (`Text("…")`, `Button("…")`, `Toggle("…")`, …) are localized automatically.
- Use `LocalizedStringKey` for view parameters that take text, and `String(localized: "…")`
  for `String` values (errors, model titles, status messages).
- Then add the new key to every `Localizable.strings`.

To list every key the code uses (the same data Xcode exports), let the compiler emit them:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift build --build-path /tmp/ak-strings -Xswiftc -emit-localized-strings \
  -Xswiftc -emit-localized-strings-path -Xswiftc /tmp/ak-strings/out
# /tmp/ak-strings/out/*.stringsdata are JSON files with all keys
```
