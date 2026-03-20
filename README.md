# Как запускать:

```bash
chmod +x setup_imba_bspwm.sh
./setup_imba_bspwm.sh
sudo reboot
```

Что получится после ребута:

* система автоматически залогинится в `tty1`
* `startx` поднимет `bspwm`
* сверху будет панель `polybar`
* в трее появятся **Wi-Fi** и **Bluetooth**
* будет **прозрачный терминал**
* можно поставить **свои обои**
* при открытии терминала будет показываться **fastfetch**
* `Alt+Shift+L` будет блокировать экран через `i3lock`, а `xss-lock` будет вызывать локер и на DPMS/suspend-событиях. ([Arch Linux][3])

Если хочешь, следующим сообщением я сделаю тебе **вторую версию этого же скрипта в стиле Catppuccin**, с более дорогими цветами, power menu и красивым shutdown/reboot/lock launcher.

[1]: https://archlinux.org/packages/extra/x86_64/polybar/?utm_source=chatgpt.com "polybar 3.7.2-2 (x86_64)"
[2]: https://wiki.archlinux.org/title/Getty?utm_source=chatgpt.com "getty - ArchWiki"
[3]: https://archlinux.org/packages/extra/x86_64/network-manager-applet/?utm_source=chatgpt.com "network-manager-applet 1.36.0-1 (x86_64)"
