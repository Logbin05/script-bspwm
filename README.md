# BSPWM-UNICRON

Simple, stylish desktop setup for Arch Linux (`bspwm + polybar + rofi`).

## Language / Язык

- English docs: [README.en.md](./README.en.md)
- Русская документация: [README.ru.md](./README.ru.md)

## Quick start

```bash
chmod +x script.sh
./script.sh
sudo reboot
```

Run installer as a regular user (not root).

## Project architecture

```text
script.sh                 # orchestration only
lib/
  legacy.sh              # compatibility layer (current function implementations)
  packages.sh            # package/service bootstrap
  theme.sh               # theme + config generation
  ui.sh                  # desktop UX scripts/windows/hotkeys
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

## License

- Main license (English): [LICENSE](./LICENSE)
- Russian version: [LICENSE.ru.md](./LICENSE.ru.md)
