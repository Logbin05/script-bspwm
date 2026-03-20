#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -eq 0 ]]; then
  echo "Запускай этот скрипт от обычного пользователя, не от root."
  exit 1
fi

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
CONFIG_DIR="${USER_HOME}/.config"
LOCAL_BIN="${USER_HOME}/.local/bin"
WALL_DIR="${USER_HOME}/Pictures/Wallpapers"
WALLPAPER="${WALL_DIR}/wallpaper.jpg"

BATTERY_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "$d/type" ]] && grep -qx 'Battery' "$d/type" && basename "$d" && break
done || true)"
AC_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "$d/type" ]] && grep -Eqx 'Mains|USB|USB_C|USB_PD' "$d/type" && basename "$d" && break
done || true)"

BATTERY_NAME="${BATTERY_NAME:-BAT0}"
AC_NAME="${AC_NAME:-AC}"

PACKAGES=(
  bspwm
  sxhkd
  xorg-server
  xorg-xinit
  xorg-xrandr
  xorg-xsetroot
  alacritty
  picom
  feh
  polybar
  rofi
  dunst
  firefox
  thunar
  networkmanager
  network-manager-applet
  blueman
  bluez
  bluez-utils
  i3lock
  xss-lock
  pavucontrol
  pipewire
  pipewire-pulse
  wireplumber
  fastfetch
  xdotool
  lxappearance
  papirus-icon-theme
  ttf-jetbrains-mono-nerd
  noto-fonts
  noto-fonts-emoji
  dbus
)

info() {
  printf "\n[INFO] %s\n" "$1"
}

backup_if_exists() {
  local target="$1"
  if [[ -e "$target" ]]; then
    cp -r "$target" "${target}.bak.$(date +%s)"
  fi
}

info "Обновление системы и установка пакетов"
sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"

info "Включение системных сервисов"
sudo systemctl enable NetworkManager
sudo systemctl enable bluetooth
sudo systemctl enable wireplumber

info "Создание директорий"
mkdir -p \
  "${CONFIG_DIR}/bspwm" \
  "${CONFIG_DIR}/sxhkd" \
  "${CONFIG_DIR}/polybar" \
  "${CONFIG_DIR}/rofi" \
  "${CONFIG_DIR}/dunst" \
  "${CONFIG_DIR}/picom" \
  "${CONFIG_DIR}/alacritty" \
  "${LOCAL_BIN}" \
  "${WALL_DIR}"

info "Бэкап старых конфигов"
backup_if_exists "${CONFIG_DIR}/bspwm/bspwmrc"
backup_if_exists "${CONFIG_DIR}/sxhkd/sxhkdrc"
backup_if_exists "${CONFIG_DIR}/polybar/config.ini"
backup_if_exists "${CONFIG_DIR}/rofi/config.rasi"
backup_if_exists "${CONFIG_DIR}/dunst/dunstrc"
backup_if_exists "${CONFIG_DIR}/picom/picom.conf"
backup_if_exists "${CONFIG_DIR}/alacritty/alacritty.toml"
backup_if_exists "${USER_HOME}/.xinitrc"
backup_if_exists "${USER_HOME}/.bash_profile"
backup_if_exists "${USER_HOME}/.bashrc"
backup_if_exists "${USER_HOME}/.xprofile"

info "Скрипт блокировки экрана"
cat > "${LOCAL_BIN}/lock-screen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec i3lock -n -c 0f111a
EOF
chmod +x "${LOCAL_BIN}/lock-screen"

info "Скрипт dropdown-терминала"
cat > "${LOCAL_BIN}/dropdown-terminal" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

alacritty --class dropdown &
sleep 0.45

wid="$(xdotool search --sync --onlyvisible --class dropdown | tail -n 1)"
screen="$(xrandr | awk '/\*/ {print $1; exit}')"

sw="${screen%x*}"
sh="${screen#*x}"

ww=$(( sw * 78 / 100 ))
wh=$(( sh * 72 / 100 ))
wx=$(( (sw - ww) / 2 ))
wy=36

xdotool windowsize "$wid" "$ww" "$wh"
xdotool windowmove "$wid" "$wx" "$wy"
EOF
chmod +x "${LOCAL_BIN}/dropdown-terminal"

info "Скрипт обновления системы"
cat > "${LOCAL_BIN}/update-system" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec alacritty -e bash -lc 'sudo pacman -Syu; echo; read -n 1 -s -r -p "Нажми любую клавишу для закрытия..."'
EOF
chmod +x "${LOCAL_BIN}/update-system"

info "Конфиг bspwm"
cat > "${CONFIG_DIR}/bspwm/bspwmrc" <<'EOF'
#!/bin/sh

pgrep -x sxhkd >/dev/null || sxhkd &
pgrep -x picom >/dev/null || picom --config "$HOME/.config/picom/picom.conf" &
pgrep -x dunst >/dev/null || dunst &
pgrep -x nm-applet >/dev/null || nm-applet &
pgrep -x blueman-applet >/dev/null || blueman-applet &
pgrep -x xss-lock >/dev/null || xss-lock --transfer-sleep-lock -- "$HOME/.local/bin/lock-screen" &
pkill polybar >/dev/null 2>&1 || true
polybar main &

xsetroot -cursor_name left_ptr

if [ -f "$HOME/Pictures/Wallpapers/wallpaper.jpg" ]; then
  feh --bg-fill "$HOME/Pictures/Wallpapers/wallpaper.jpg"
fi

bspc monitor -d I II III IV V VI VII VIII IX X

bspc config border_width 2
bspc config window_gap 14
bspc config split_ratio 0.52
bspc config borderless_monocle true
bspc config gapless_monocle true
bspc config focus_follows_pointer true
bspc config pointer_modifier mod1
bspc config focused_border_color "#89B4FA"
bspc config normal_border_color "#313244"
bspc config active_border_color "#74C7EC"
bspc config presel_feedback_color "#F38BA8"

# dropdown terminal
bspc rule -a dropdown state=floating sticky=on center=on
EOF
chmod +x "${CONFIG_DIR}/bspwm/bspwmrc"

info "Конфиг sxhkd"
cat > "${CONFIG_DIR}/sxhkd/sxhkdrc" <<'EOF'
# dropdown terminal
super + Return
    ~/.local/bin/dropdown-terminal

alt + Return
    ~/.local/bin/dropdown-terminal

# normal terminal
super + shift + Return
    alacritty

alt + shift + Return
    alacritty

# app launcher
super + d
    rofi -show drun

alt + d
    rofi -show drun

# browser
super + b
    firefox

alt + b
    firefox

# file manager
super + e
    thunar

alt + e
    thunar

# close focused window
super + q
    bspc node -c

alt + q
    bspc node -c

# lock screen
super + shift + l
    ~/.local/bin/lock-screen

alt + shift + l
    ~/.local/bin/lock-screen

# update system
super + shift + u
    ~/.local/bin/update-system

alt + shift + u
    ~/.local/bin/update-system

# restart sxhkd
super + shift + r
    pkill sxhkd; sxhkd &

alt + shift + r
    pkill sxhkd; sxhkd &

# restart bspwm config
super + shift + b
    bspc wm -r

alt + shift + b
    bspc wm -r

# desktops
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

alt + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# move node to desktop
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

alt + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

# focus windows
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

alt + {h,j,k,l}
    bspc node -f {west,south,north,east}

# swap windows
super + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

alt + shift + {h,j,k,l}
    bspc node -s {west,south,north,east}

# fullscreen / floating / monocle
super + f
    bspc node -t fullscreen

alt + f
    bspc node -t fullscreen

super + shift + space
    bspc node -t floating

alt + shift + space
    bspc node -t floating

super + m
    bspc desktop -l next

alt + m
    bspc desktop -l next

# volume
XF86AudioRaiseVolume
    pactl set-sink-volume @DEFAULT_SINK@ +5%

XF86AudioLowerVolume
    pactl set-sink-volume @DEFAULT_SINK@ -5%

XF86AudioMute
    pactl set-sink-mute @DEFAULT_SINK@ toggle
EOF

info "Конфиг polybar"
cat > "${CONFIG_DIR}/polybar/config.ini" <<EOF
[colors]
background = #D90F111A
background-alt = #1A1D29
foreground = #E6E9EF
primary = #89B4FA
secondary = #F5C2E7
accent = #A6E3A1
urgent = #F38BA8
muted = #6C7086

[bar/main]
width = 96%
offset-x = 2%
offset-y = 8
height = 34
radius = 14
background = \${colors.background}
foreground = \${colors.foreground}
border-size = 1
border-color = #2A2D3A
padding-left = 2
padding-right = 2
module-margin = 2
font-0 = JetBrainsMono Nerd Font:size=10;2
font-1 = Noto Color Emoji:size=10;1
modules-left = bspwm
modules-center = xwindow
modules-right = battery pulseaudio tray
enable-ipc = true

[module/bspwm]
type = internal/bspwm
label-focused = 󰮯 %name%
label-focused-background = \${colors.primary}
label-focused-foreground = #11111b
label-focused-padding = 2
label-occupied = 󰊠 %name%
label-occupied-padding = 2
label-empty = 󰧟 %name%
label-empty-foreground = \${colors.muted}
label-empty-padding = 2

[module/xwindow]
type = internal/xwindow
label = %title:0:55:...%

[module/battery]
type = internal/battery
battery = ${BATTERY_NAME}
adapter = ${AC_NAME}
full-at = 99
poll-interval = 5
format-charging =   <label-charging>
format-discharging =   <label-discharging>
format-full =   <label-full>
label-charging = %percentage%%
label-discharging = %percentage%%
label-full = 100%%

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <label-volume>
label-volume =   %percentage%%
label-muted = 󰝟  muted

[module/tray]
type = internal/tray
tray-spacing = 8
EOF

info "Конфиг alacritty"
cat > "${CONFIG_DIR}/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.84
padding = { x = 10, y = 10 }
decorations = "None"

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size = 10.0

[colors.primary]
background = "#0F111A"
foreground = "#E6E9EF"

[colors.cursor]
text = "#0F111A"
cursor = "#89B4FA"

[colors.normal]
black = "#1A1D29"
red = "#F38BA8"
green = "#A6E3A1"
yellow = "#F9E2AF"
blue = "#89B4FA"
magenta = "#F5C2E7"
cyan = "#94E2D5"
white = "#BAC2DE"

[colors.bright]
black = "#585B70"
red = "#F38BA8"
green = "#A6E3A1"
yellow = "#F9E2AF"
blue = "#89B4FA"
magenta = "#F5C2E7"
cyan = "#94E2D5"
white = "#A6ADC8"
EOF

info "Конфиг picom"
cat > "${CONFIG_DIR}/picom/picom.conf" <<'EOF'
backend = "glx";
vsync = true;

shadow = true;
shadow-radius = 20;
shadow-opacity = 0.28;
shadow-offset-x = -12;
shadow-offset-y = -12;

corner-radius = 14;
round-borders = 12;

fading = true;
fade-in-step = 0.04;
fade-out-step = 0.04;

inactive-opacity = 0.94;
active-opacity = 1.0;
frame-opacity = 1.0;

blur-method = "dual_kawase";
blur-strength = 6;

opacity-rule = [
  "84:class_g = 'Alacritty'",
  "90:class_g = 'dropdown'",
  "92:class_g = 'Rofi'"
];
EOF

info "Конфиг dunst"
cat > "${CONFIG_DIR}/dunst/dunstrc" <<'EOF'
[global]
    monitor = 0
    follow = mouse
    width = 360
    height = 100
    origin = top-right
    offset = 20x50
    corner_radius = 12
    frame_width = 2
    gap_size = 8
    font = JetBrainsMono Nerd Font 10
    background = "#0F111A"
    foreground = "#E6E9EF"
    frame_color = "#89B4FA"
    separator_color = frame
    timeout = 5
    markup = full
    format = "<b>%s</b>\n%b"
EOF

info "Конфиг rofi"
cat > "${CONFIG_DIR}/rofi/config.rasi" <<'EOF'
configuration {
  modi: "drun,run,window";
  show-icons: true;
  icon-theme: "Papirus";
}

* {
  font: "JetBrainsMono Nerd Font 11";
  bg: #0f111aee;
  bg-alt: #1a1d29ff;
  fg: #e6e9ef;
  sel: #89b4faff;
  sel-fg: #11111bff;
  border: #89b4faff;
}

window {
  width: 40%;
  border: 2px;
  border-color: @border;
  border-radius: 12px;
  background-color: @bg;
}

mainbox {
  padding: 12px;
  background-color: @bg;
}

inputbar {
  padding: 10px;
  border-radius: 10px;
  background-color: @bg-alt;
}

listview {
  lines: 10;
  columns: 1;
  spacing: 8px;
  padding: 8px 0 0;
  background-color: @bg;
}

element {
  padding: 10px;
  border-radius: 10px;
  background-color: transparent;
  text-color: @fg;
}

element selected {
  background-color: @sel;
  text-color: @sel-fg;
}
EOF

info "X profile"
cat > "${USER_HOME}/.xprofile" <<'EOF'
export GTK_THEME=Adwaita:dark
export XCURSOR_SIZE=24
EOF

info "Автозапуск X и автоперезапуск bspwm"
cat > "${USER_HOME}/.xinitrc" <<'EOF'
#!/bin/sh
export XDG_CURRENT_DESKTOP=bspwm
while true; do
  dbus-run-session bspwm
  sleep 1
done
EOF
chmod +x "${USER_HOME}/.xinitrc"

cat > "${USER_HOME}/.bash_profile" <<'EOF'
if [[ -z "${DISPLAY:-}" ]] && [[ "${XDG_VTNR:-0}" -eq 1 ]]; then
  exec startx
fi
EOF

info "Автологин на tty1"
sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --noclear %I \$TERM
EOF

info "Обновление systemd конфигурации"
sudo systemctl daemon-reload

info "fastfetch в bashrc"
if ! grep -q "fastfetch" "${USER_HOME}/.bashrc" 2>/dev/null; then
  cat >> "${USER_HOME}/.bashrc" <<'EOF'

if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi
EOF
fi

info "Права владельца"
sudo chown -R "${USER_NAME}:${USER_NAME}" \
  "${CONFIG_DIR}" \
  "${USER_HOME}/.local" \
  "${WALL_DIR}" \
  "${USER_HOME}/.xinitrc" \
  "${USER_HOME}/.bash_profile" \
  "${USER_HOME}/.bashrc" \
  "${USER_HOME}/.xprofile"

info "Готово"
echo
echo "Что осталось:"
echo "1. Положи свои обои сюда:"
echo "   ${WALLPAPER}"
echo
echo "2. Перезагрузи систему:"
echo "   sudo reboot"
echo
echo "3. Основные хоткеи:"
echo "   Alt+Return         -> dropdown-терминал сверху"
echo "   Alt+Shift+Return   -> обычный терминал"
echo "   Alt+d              -> меню приложений"
echo "   Alt+b              -> Firefox"
echo "   Alt+e              -> Thunar"
echo "   Alt+q              -> закрыть окно"
echo "   Alt+Shift+l        -> блокировка экрана"
echo "   Alt+Shift+u        -> обновление системы"
echo
echo "Обычный выход из bspwm хоткеями отключён."
echo "Аварийный доступ оставлен через Ctrl+Alt+F2."
