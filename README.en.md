# BSPWM-UNICRON (English)

This project installs a complete desktop environment on Arch Linux:

- `bspwm` tiling WM
- macOS-like `polybar` with Wi-Fi/Bluetooth/Settings emphasis
- `rofi` app deck and menus
- custom lock screen
- helper scripts for themes, wallpapers, screenshots, archives, updates, and private file access

## 1) Requirements

- Arch Linux
- user account with `sudo`
- X11 session (`bspwm` + `sxhkd`)

## 2) Install

Run as a regular user (not root):

```bash
chmod +x script.sh
./script.sh
sudo reboot
```

## 3) Main hotkeys

All major bindings work with both `Alt` and `Super`.

- `Alt+Return` / `Super+Return`: dropdown terminal
- `Alt+d` / `Super+d`: app deck
- `Alt+c` / `Super+c`: control center
- `Alt+s` / `Super+s`: system settings
- `Alt+,` / `Super+,`: app settings
- `Alt+Shift+p` / `Super+Shift+p`: power menu
- `Alt+Ctrl+b` / `Super+Ctrl+b`: restart polybar
- `Alt+Ctrl+p` / `Super+Ctrl+p`: apply polybar features
- `Alt+Ctrl+t` / `Super+Ctrl+t`: pick desktop theme
- `Alt+Space` / `Super+Space`: switch keyboard layout (EN/RU)
- `Alt+Ctrl+h` / `Super+Ctrl+h`: shell docs/help (RU/EN)
- `Alt+Ctrl+z` / `Super+Ctrl+z`: timezone/NTP menu
- `Alt+Ctrl+w` / `Super+Ctrl+w`: pick wallpaper
- `Alt+Ctrl+x` / `Super+Ctrl+x`: extract archive
- `Alt+Ctrl+a` / `Super+Ctrl+a`: open `arch-access`
- `Alt+Ctrl+u` / `Super+Ctrl+u`: update setup repository
- `Alt+Ctrl+l` / `Super+Ctrl+l`: lock screen
- `Print`: full screenshot
- `Shift+Print`: area screenshot
- `Ctrl+Print`: active window screenshot
- `XF86MonBrightnessUp/Down`: brightness control (Fn combos on most laptops)
- `XF86AudioPlay/Next/Prev/Stop`: media control (Fn combos on most laptops)

## 4) Helper commands

- `~/.local/bin/launch-polybar`: launch bar with fallback config
- `~/.local/bin/polybar-refresh`: apply `features.ini` toggles
- `~/.local/bin/polybar-preset`: quick preset (`focus`, `balanced`, `monitoring`)
- `~/.local/bin/imba-theme --pick`: switch desktop theme
- `~/.local/bin/set-wallpaper --pick`: choose wallpaper
- `~/.local/bin/toggle-layout`: switch keyboard layout (EN/RU)
- `~/.local/bin/wifi-menu`: terminal Wi-Fi modal (`nmtui`)
- `~/.local/bin/bluetooth-menu`: terminal Bluetooth modal (`bluetoothctl`)
- `~/.local/bin/terminal-modals`: unified terminal modal hub (Wi-Fi/Bluetooth/etc.)
- `~/.local/bin/take-screenshot --pick`: screenshot menu
- `~/.local/bin/extract-any --pick`: extract archives (`zip/rar/7z/tar/...`)
- `~/.local/bin/open-file-manager`: file manager wrapper
- `~/.local/bin/arch-access`: privileged file access flow
- `~/.local/bin/bind-ssh-key --pick`: bind key to user ssh-agent
- `~/.local/bin/set-user-avatar --pick`: set lock-screen avatar
- `~/.local/bin/apply-monitor-layout`: re-apply multi-monitor layout
- `~/.local/bin/configure-input-devices`: trackpad/libinput tweaks
- `~/.local/bin/update-imba-script`: update repo and auto-apply `./script.sh` (use `--no-apply` to skip apply)
- `~/.local/bin/unicron-help --pick`: shell documentation with language picker
- `~/.local/bin/shell-help --pick`: short alias for shell docs (help-like command)
- `~/.local/bin/unicron-time --menu`: interactive timezone and internet-sync menu
- `~/.local/bin/shell-time --menu`: short alias for timezone/NTP menu

## 5) Key config files

- `~/.config/polybar/config.ini`: primary bar layout
- `~/.config/polybar/features.ini`: safe feature toggles
- `~/.config/polybar/fallback.ini`: emergency fallback bar
- `~/.cache/polybar/main.log`: polybar startup log
- `~/.config/sxhkd/sxhkdrc`: hotkeys
- `~/.config/bspwm/bspwmrc`: WM behavior/autostart

## 6) File manager abstraction

Use one wrapper everywhere:

```bash
~/.local/bin/open-file-manager
```

Examples:

```bash
~/.local/bin/open-file-manager --path ~/Downloads
~/.local/bin/open-file-manager --select ~/Downloads/archive.zip
FILE_MANAGER=yazi ~/.local/bin/open-file-manager
```

Supported mode values:

- `FILE_MANAGER=thunar` (default)
- `FILE_MANAGER=yazi`
- `FILE_MANAGER=<custom binary>`

## 7) Troubleshooting

### Polybar starts in fallback

Check:

```bash
tail -n 120 ~/.cache/polybar/main.log
```

Most common cause is duplicate keys in user overrides. Keep personal overrides minimal and avoid redefining the same key multiple times in one section.

### Script updater reports local changes

Use:

```bash
~/.local/bin/update-imba-script
```

The updater attempts `pull --rebase --autostash` and then auto-runs `./script.sh`.
If you only want to pull updates without applying them immediately, use:

```bash
~/.local/bin/update-imba-script --no-apply
```

If conflicts remain, resolve them in your repo and run again.

### Commands are missing in `~/.local/bin`

Re-run installer:

```bash
cd ~/script-bspwm
./script.sh
```

## 8) Project architecture

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

## 9) License

This project uses a custom source-available license:

- You can use and improve the config.
- Public redistribution, forking with published modifications, or commercial use requires:
- notifying the original author
- getting prior written consent from the original author

See full text:

- [LICENSE](./LICENSE) (English, primary)
- [LICENSE.ru.md](./LICENSE.ru.md) (Russian translation)
