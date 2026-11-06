# AK820 Studio

**Нативное приложение для macOS для настройки клавиатуры AJAZZ AK820 Pro** — без Windows и браузера.

[English version](README.md)

Фирменная программа настройки есть только под Windows (и очень ограниченное веб-приложение).
AK820 Studio делает то же самое нативно на macOS, общаясь с клавиатурой по USB HID.

![Подсветка](docs/screenshots/lighting-ru.png)

## Клавиатура

AJAZZ AK820 Pro — механическая клавиатура 75 % на гаскете, 81 клавиша, крутилка, экран TFT 0,85″,
три режима подключения (USB-C / 2,4 ГГц / Bluetooth). Продаётся также как EPOMAKER × AJAZZ и ATTACK SHARK × AJAZZ.

- Официальный магазин AJAZZ: <https://ajazzstore.com/products/ajazz-ak820-pro>
- Официальный сайт AJAZZ (драйверы, инструкции): <https://www.a-jazz.com/en/search.jsp?id=422&q=ak820>
- EPOMAKER: <https://epomaker.com/products/ajazz-ak820-pro>
- ATTACK SHARK: <https://attackshark.com/products/attackshark-ajazz-ak820-pro-75-mechanical-keyboard>
- Инструкция: <https://manuals.plus/asin/B0CMWKN55N>

Поддерживаемые USB ID: VID `0C45` (SONiX), PID `8009` / `800A` (по кабелю).

## Возможности

| Вкладка | Что умеет |
|---|---|
| Подсветка | 19 встроенных эффектов, цвет или радуга, яркость, скорость, направление; применяется сразу |
| Цвета клавиш | свой цвет каждой клавиши — рисование по схеме клавиатуры, шаблоны |
| Клавиши | переназначение на основном слое и слое Fn: клавиша / сочетание, мультимедиа, мышь, макрос, отключение |
| Макросы | текст, сочетания клавиш, паузы, клики мыши; один раз / N раз / по кругу / пока зажата / по шагу |
| Экран | картинка или GIF (до 140 кадров) на экран 128×128 с предпросмотром; синхронизация часов |
| Настройки | автосон, режим Fn, защита от дребезга, блокировки Win / Alt+Tab / Alt+F4, язык, экспорт / импорт |
| Строка меню | быстрые эффекты, цвета, яркость, часы, автозапуск |

Всё сохраняется **в самой клавиатуре** и работает на любом компьютере и при любом подключении.
Настраивать можно **только по кабелю USB-C** (как и в официальной программе).

Языки: английский, русский. Новый язык — это один файл, см. [TRANSLATING.md](TRANSLATING.md).

## Сборка и установка

Нужны macOS 14+ и Xcode (макросам SwiftUI нужен полный тулчейн Xcode, одних Command Line Tools мало).

```sh
git clone https://github.com/usharik/ak820-studio.git
cd ak820-studio
./scripts/build-app.sh
cp -R "dist/AK820 Studio.app" /Applications/
```

Приложение подписано ad-hoc. Если macOS не даёт его открыть: правый клик → «Открыть».

Утилита для терминала: `dist/ak820ctl` (`info`, `battery`, `clock`, `lights`, `image`; `-v` показывает пакеты).

## Состояние

Проверено на настоящей AK820 Pro (PID `8009`): обнаружение, заряд батареи, синхронизация часов.
Остальные функции используют форматы пакетов, проверенные на этой модели в проектах ниже, но в этом
приложении пока протестированы мало. Если что-то не работает, откройте
**Настройки → Журнал обмена с клавиатурой** и приложите его содержимое к issue.

Вернуть заводскую раскладку: **Клавиши → Сбросить всё → Записать в клавиатуру**.

Пока не поддерживается: настройка по 2,4 ГГц / Bluetooth, подсветка под музыку.

## Благодарности и использованные материалы

Протокол восстановлен сообществом по официальному драйверу для Windows (`DeviceDriver.exe` v1.0.0.5).
AK820 Studio — новая реализация на основе этой работы:

- [gha-projects/ak820-mac](https://github.com/gha-projects/ak820-mac) — утилита для AK820 Pro на macOS;
  проверенные на железе последовательности пакетов, контрольные суммы, формат макросов (основной источник).
- [Twyx22/ak820-center](https://github.com/Twyx22/ak820-center) — приложение для Linux; `PROTOCOL.md` и
  официальная раскладка (`rgb-keyboard.xml`), из которой сгенерирована схема клавиш.
- [wsclx/ak820pro-modder](https://github.com/wsclx/ak820pro-modder) и
  [adamauthor/ak820pro-modder](https://github.com/adamauthor/ak820pro-modder) — исследование протокола обеих версий прошивки.
- [igordev96/AJAZZ-AK820-Pro-Driver](https://github.com/igordev96/AJAZZ-AK820-Pro-Driver) — конфигуратор на WebHID.
- [hcristosm/ak820-linux](https://github.com/hcristosm/ak820-linux) — утилита для Linux (RGB, экран, часы).

Более ранние работы сообщества, на которых построены эти проекты:
[gohv/EPOMAKER-Ajazz-AK820-Pro](https://github.com/gohv/EPOMAKER-Ajazz-AK820-Pro),
[TaxMachine/ajazz-keyboard-software-linux](https://github.com/TaxMachine/ajazz-keyboard-software-linux),
[KyleBoyer/TFTTimeSync-node](https://github.com/KyleBoyer/TFTTimeSync-node),
[Aiacos/ajazz-control-center](https://github.com/Aiacos/ajazz-control-center),
[gusleig/ajazz-ak820-pro-mac](https://github.com/gusleig/ajazz-ak820-pro-mac),
[MemerGamer/AjazzAk820ProUnofficialWebdriver](https://github.com/MemerGamer/AjazzAk820ProUnofficialWebdriver).

См. [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Неофициальный проект, не связан с AJAZZ или EPOMAKER. Используйте на свой страх и риск.

## Лицензия

MIT — см. [LICENSE](LICENSE).
