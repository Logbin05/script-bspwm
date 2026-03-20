# Imba bspwm setup

Скрипт `script.sh` поднимает аккуратный `bspwm`-desktop с цельным визуальным стилем:

- glass-like `polybar` с рабочими столами, названием активного окна, обновлениями, CPU, RAM, звуком, Wi-Fi, Bluetooth, батареей и временем
- `App Deck` для выбора приложений через красивую сетку `rofi`
- `quick hub`, отдельные окна настроек приложений и системных настроек
- нормальный `lock screen` через `LightDM + slick-greeter + light-locker` с логином, паролем и аватаром
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
- `Alt+s` откроет системные настройки
- `Alt+,` откроет настройки приложений
- `Alt+Shift+p` откроет power menu
- `Alt+Shift+l` откроет lock screen с логином/паролем
- при открытии интерактивного терминала будет показываться `fastfetch`

Все основные бинды продублированы и на `Super`.

## Главные хоткеи

- `Alt+Return` или `Super+Return` -> dropdown-терминал
- `Alt+Shift+Return` или `Super+Shift+Return` -> обычный терминал
- `Alt+d` или `Super+d` -> выбор приложений
- `Alt+c` или `Super+c` -> quick hub
- `Alt+s` или `Super+s` -> системные настройки
- `Alt+,` или `Super+,` -> настройки приложений
- `Alt+Shift+p` или `Super+Shift+p` -> питание
- `Alt+b` или `Super+b` -> Firefox
- `Alt+e` или `Super+e` -> Thunar
- `Alt+q` или `Super+q` -> закрыть окно
- `Alt+Shift+u` или `Super+Shift+u` -> обновление системы

## Аватар для блокировки

Поставить свою аватарку можно так:

```bash
~/.local/bin/set-user-avatar --pick
```

Если заранее положить файл в `~/Pictures/avatar.png`, установщик попробует применить его автоматически.

## Обои

Положи свои обои сюда:

```text
~/Pictures/Wallpapers/wallpaper.jpg
```
