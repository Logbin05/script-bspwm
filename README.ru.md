# BSPWM-UNICRON (Русская версия)

Этот проект ставит цельное desktop-окружение на Arch Linux:

- `bspwm` (тайлинговый WM)
- `polybar` в стиле macOS с акцентом на Wi-Fi/Bluetooth/Settings
- `rofi` для App Deck и меню
- кастомный lock screen
- helper-скрипты для тем, обоев, скриншотов, архивов, обновлений и доступа к приватным файлам

## 1) Требования

- Arch Linux
- обычный пользователь с `sudo`
- X11-сессия (`bspwm` + `sxhkd`)

## 2) Установка

Запускай от обычного пользователя (не от root):

```bash
chmod +x script.sh
./script.sh
sudo reboot
```

## 3) Главные хоткеи

Все основные бинды работают и с `Alt`, и с `Super`.

- `Alt+Return` / `Super+Return`: выпадающий терминал
- `Alt+d` / `Super+d`: App Deck
- `Alt+c` / `Super+c`: control center
- `Alt+s` / `Super+s`: системные настройки
- `Alt+,` / `Super+,`: настройки приложений
- `Alt+Shift+p` / `Super+Shift+p`: меню питания
- `Alt+Ctrl+b` / `Super+Ctrl+b`: перезапуск polybar
- `Alt+Ctrl+p` / `Super+Ctrl+p`: применить feature-тогглы polybar
- `Alt+Ctrl+t` / `Super+Ctrl+t`: выбор темы интерфейса
- `Alt+Space` / `Super+Space`: сменить раскладку (EN/RU)
- `Alt+Ctrl+h` / `Super+Ctrl+h`: shell help/документация (RU/EN)
- `Alt+Ctrl+z` / `Super+Ctrl+z`: меню часового пояса и NTP
- `Alt+Ctrl+w` / `Super+Ctrl+w`: выбор обоев
- `Alt+Ctrl+x` / `Super+Ctrl+x`: распаковка архива
- `Alt+Ctrl+a` / `Super+Ctrl+a`: запуск `arch-access`
- `Alt+Ctrl+u` / `Super+Ctrl+u`: обновление setup-репозитория
- `Alt+Ctrl+l` / `Super+Ctrl+l`: lock screen
- `Print`: скриншот всего экрана
- `Shift+Print`: скриншот области
- `Ctrl+Print`: скриншот активного окна
- `Fn+F1..F12`: управление звуком/медиа/яркостью (через F-row бинды)

## 4) Основные helper-команды

- `~/.local/bin/launch-polybar`: запуск бара с fallback-конфигом
- `~/.local/bin/polybar-refresh`: применить toggles из `features.ini`
- `~/.local/bin/polybar-preset`: быстрый профиль (`focus`, `balanced`, `monitoring`)
- `~/.local/bin/imba-theme --pick`: переключить тему интерфейса
- `~/.local/bin/set-wallpaper --pick`: выбрать обои
- `~/.local/bin/toggle-layout`: сменить раскладку клавиатуры (EN/RU)
- `~/.local/bin/wifi-menu`: терминальная Wi-Fi модалка (`nmtui`)
- `~/.local/bin/bluetooth-menu`: терминальная Bluetooth модалка (`bluetoothctl`)
- `~/.local/bin/terminal-modals`: единый терминальный хаб модалок (Wi-Fi/Bluetooth/и т.д.)
- `~/.local/bin/take-screenshot --pick`: меню скриншотов
- `~/.local/bin/extract-any --pick`: распаковка архивов (`zip/rar/7z/tar/...`)
- `~/.local/bin/open-file-manager`: единая команда файлового менеджера
- `~/.local/bin/arch-access`: доступ к приватным файлам
- `~/.local/bin/bind-ssh-key --pick`: привязать ключ к user ssh-agent
- `~/.local/bin/set-user-avatar --pick`: поставить аватар для lock screen
- `~/.local/bin/apply-monitor-layout`: переприменить раскладку мониторов
- `~/.local/bin/configure-input-devices`: твики trackpad/libinput
- `~/.local/bin/update-imba-script`: обновить репозиторий и автоматически применить `./script.sh` (флаг `--no-apply` выключает авто-применение)
- `~/.local/bin/unicron-help --pick`: документация в shell с выбором языка
- `~/.local/bin/shell-help --pick`: короткий alias для shell-документации (аналог help)
- `~/.local/bin/unicron-time --menu`: интерактивное меню timezone и синхронизации времени
- `~/.local/bin/shell-time --menu`: короткий alias для timezone/NTP меню

## 5) Важные конфиги

- `~/.config/polybar/config.ini`: основной bar layout
- `~/.config/polybar/features.ini`: безопасные toggles модулей
- `~/.config/polybar/fallback.ini`: аварийный bar
- `~/.cache/polybar/main.log`: лог запуска polybar
- `~/.config/sxhkd/sxhkdrc`: хоткеи
- `~/.config/bspwm/bspwmrc`: поведение WM и автозапуск

## 6) Абстракция файлового менеджера

Везде используется один wrapper:

```bash
~/.local/bin/open-file-manager
```

Примеры:

```bash
~/.local/bin/open-file-manager --path ~/Downloads
~/.local/bin/open-file-manager --select ~/Downloads/archive.zip
FILE_MANAGER=yazi ~/.local/bin/open-file-manager
```

Поддерживаемые режимы:

- `FILE_MANAGER=thunar` (по умолчанию)
- `FILE_MANAGER=yazi`
- `FILE_MANAGER=<custom binary>`

## 7) Troubleshooting

### Polybar стартует только в fallback

Проверь лог:

```bash
tail -n 120 ~/.cache/polybar/main.log
```

Чаще всего причина в дублях ключей внутри пользовательских override-файлов. Не дублируй один и тот же ключ в одной секции.

### Updater пишет про локальные изменения

Запусти:

```bash
~/.local/bin/update-imba-script
```

Updater делает `pull --rebase --autostash`, а затем автоматически запускает `./script.sh`.
Если нужно только подтянуть изменения без применения, используй:

```bash
~/.local/bin/update-imba-script --no-apply
```

Если остались конфликты, разрули их в репозитории и запусти команду снова.

### В `~/.local/bin` нет нужных команд

Просто повторно запусти установщик:

```bash
cd ~/script-bspwm
./script.sh
```

## 8) Архитектура проекта

```text
script.sh                 # orchestration only
lib/
  legacy.sh              # compatibility layer (текущая реализация функций)
  packages.sh            # пакеты/сервисы/базовая подготовка
  theme.sh               # генерация темы и конфигов
  ui.sh                  # окна, меню, хоткеи и desktop UX
  access.sh              # arch-access + ssh/avatar runtime
templates/
  polybar/
  rofi/
  gtk/
  dunst/
  picom/
  alacritty/
bin/
  imba-apply-theme
  imba-control-center
  open-file-manager
  arch-access
```

## 9) Лицензия

Проект использует кастомную source-available лицензию:

- Конфиг можно брать и улучшать.
- Публичное распространение, форк с опубликованными изменениями или коммерческое использование требует:
- уведомить автора оригинального репозитория
- получить предварительное письменное согласие автора

Полный текст:

- [LICENSE](./LICENSE) (English, основная версия)
- [LICENSE.ru.md](./LICENSE.ru.md) (русская версия)
