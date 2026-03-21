# Imba bspwm setup

Скрипт `script.sh` поднимает аккуратный `bspwm`-desktop с цельным визуальным стилем:

- минималистичный и акцентный `polybar`: рабочие столы, активное окно, звук, Wi-Fi, Bluetooth, дата, обновления, трей и power
- обязательные иконки в bar: `Wi-Fi`, `Bluetooth`, `Settings` (macOS-like подача)
- компактные столы `1..n` в баре и отдельный индикатор текущего рабочего стола сбоку
- стабильное контекстное меню bar (right-click + fallback через `yad`, если `rofi` не открылся)
- отдельный `~/.config/polybar/user.ini` для кастомизации bar без правки core-конфига
- отдельный `~/.config/polybar/features.ini` с toggles того, какую инфу показывать в bar
- быстрые пресеты бара через `~/.local/bin/polybar-preset` (`focus`, `balanced`, `monitoring`)
- `App Deck` для выбора приложений через красивую сетку `rofi`
- `quick hub`, отдельные окна настроек приложений и системных настроек
- полностью кастомный `lock screen` на `i3lock-color`: blur фон, время/дата, акцентные состояния, аватар и fallback на greeter
- `ssh-agent`, привязанный к учётке, плюс helper для привязки SSH ключа без ручного запуска агента
- helper для установки своих обоев: `~/.local/bin/set-wallpaper --pick`
- поддержка 2+ мониторов: авто-раскладка рабочих столов и запуск bar на каждом мониторе
- поддержка трекпадов: tap-to-click, natural scroll и libinput-tweaks
- команда `~/.local/bin/arch-access` для доступа к приватным файлам и директориям через `sudoedit`/root-shell
- мягкие fade/blur/shadow-эффекты через `picom`
- прозрачный `Alacritty`, тёмные уведомления `dunst`, минималистичные иконки и единая палитра

## Запуск

Запускай от обычного пользователя, не от `root`.

```bash
chmod +x script.sh
./script.sh
sudo reboot
```

## Что будет после ребута

- `LightDM` автоматически поднимет `bspwm`
- сверху появится информативный хедбар
- `Alt+d` откроет `App Deck`
- `Alt+c` откроет `quick hub`
- `Alt+Ctrl+c` откроет контекстное меню bar
- `Alt+s` откроет системные настройки
- `Alt+,` откроет настройки приложений
- `Alt+Shift+p` откроет power menu
- `Alt+Ctrl+p` применит bar по `~/.config/polybar/features.ini`
- `Alt+Shift+l` откроет новый кастомный lock screen
- `Alt+Ctrl+a` откроет `arch-access` для приватных файлов
- `Alt+Ctrl+u` проверит обновления самого setup-скрипта
- `Alt+Ctrl+w` откроет выбор своих обоев
- `Alt+Ctrl+m` переприменит layout мониторов и перезапустит bar
- при открытии интерактивного терминала будет показываться `fastfetch`
- `ssh-agent` будет подниматься как user-service для текущей учётки
- bar можно тюнить через `~/.config/polybar/user.ini`, затем применить `Alt+Shift+b`
- bar включается по умолчанию (автостарт в `bspwm`) и поднимается сразу после установки, если ты уже в GUI
- правый клик на модулях launcher/current-desktop/window/volume/network/bluetooth/date/power открывает контекстное меню bar

Все основные бинды продублированы и на `Super`.

## Главные хоткеи

- `Alt+Return` или `Super+Return` -> терминал в обычном тайлинг-режиме
- `Alt+Shift+Return` или `Super+Shift+Return` -> ещё один терминал
- `Alt+d` или `Super+d` -> выбор приложений
- `Alt+c` или `Super+c` -> quick hub
- `Alt+s` или `Super+s` -> системные настройки
- `Alt+,` или `Super+,` -> настройки приложений
- `Alt+Shift+p` или `Super+Shift+p` -> питание
- `Alt+Ctrl+p` или `Super+Ctrl+p` -> применить `Polybar` из `features.ini`
- `Alt+b` или `Super+b` -> Firefox
- `Alt+e` или `Super+e` -> Thunar
- `Alt+q` или `Super+q` -> закрыть окно
- `Alt+Ctrl+b` или `Super+Ctrl+b` -> перезапуск `polybar`
- `Alt+Ctrl+c` или `Super+Ctrl+c` -> контекстное меню bar
- `Alt+Ctrl+a` или `Super+Ctrl+a` -> `arch-access` (приватные файлы)
- `Alt+Ctrl+u` или `Super+Ctrl+u` -> обновление setup-скрипта
- `Alt+Ctrl+w` или `Super+Ctrl+w` -> установить свои обои
- `Alt+Ctrl+m` или `Super+Ctrl+m` -> обновить layout мониторов + перезапустить bar
- `Alt+Shift+u` или `Super+Shift+u` -> обновление системы

`Polybar` теперь доступен и в системных настройках, и в настройках приложений.

## Аватар для блокировки

Поставить свою аватарку можно так:

```bash
~/.local/bin/set-user-avatar --pick
```

Если заранее положить файл в `~/Pictures/avatar.png`, установщик попробует применить его автоматически.

## SSH ключ и agent

Установщик поднимает `ssh-agent` как user-level socket и экспортирует `SSH_AUTH_SOCK` в сессию.

Если в `~/.ssh/` уже лежит один из стандартных ключей, он будет привязан автоматически. Вручную выбрать свой ключ можно так:

```bash
~/.local/bin/bind-ssh-key --pick
```

После этого не нужно будет вручную запускать `ssh-agent` или каждый раз заново настраивать его для терминалов.

## Обновление setup-скрипта

Скрипт теперь можно обновлять прямо из репозитория:

```bash
~/.local/bin/update-imba-script
```

Если нужно вручную указать repo:

```bash
~/.local/bin/update-imba-script /путь/до/репозитория
```

Или один раз сохранить источник обновлений:

```bash
~/.local/bin/update-imba-script --set-source /путь/до/репозитория
```

## Доступ к приватным файлам

Для root-доступа к защищённым путям используй:

```bash
~/.local/bin/arch-access
```

- если выбрать директорию, откроется root-shell в этой папке
- если выбрать файл, он откроется через `sudoedit`
- можно сразу передать путь аргументом:

```bash
~/.local/bin/arch-access /etc/pacman.conf
```

## Кастомизация Polybar

Основной конфиг генерируется в `~/.config/polybar/config.ini`, а твои личные переопределения в:

```text
~/.config/polybar/user.ini
```

Тогглы модулей, чтобы реально выбрать какую инфу показывать в bar:

```text
~/.config/polybar/features.ini
```

В `user.ini` можно менять:

- высоту/радиус/отступы бара
- набор модулей слева/в центре/справа
- акцентные цвета
- формат времени и длину заголовка окна

После правок `features.ini` применить:

```bash
~/.local/bin/polybar-refresh
```

Быстрый выбор готового профиля:

```bash
~/.local/bin/polybar-preset
```

После изменений нажми `Alt+Shift+b`, чтобы перезапустить `bspwm` и применить новый bar.

Если bar не появился, проверь лог:

```text
~/.cache/polybar/main.log
```

`launch-polybar` теперь сначала пробует основной конфиг, а если он не стартует, автоматически поднимает `~/.config/polybar/fallback.ini`.

## Обои

Быстрый способ поставить свои обои:

```bash
~/.local/bin/set-wallpaper --pick
```

Обои сохраняются как `~/Pictures/Wallpapers/wallpaper.jpg` и применяются автоматически при старте сессии.

## Мониторы 2+

Для 2+ мониторов раскладка рабочих столов применяется автоматически (`1..n`) и bar запускается на каждом дисплее.

Если подключил/отключил монитор на горячую, быстро перепримени:

```bash
~/.local/bin/apply-monitor-layout
~/.local/bin/launch-polybar
```

## Трекпад

Для трекпада есть helper:

```bash
~/.local/bin/configure-input-devices
```

Он включает `tap-to-click`, `natural scrolling` и `disable while typing` для найденных touchpad/trackpad устройств.
