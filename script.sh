#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID} -eq 0 ]]; then
  echo "Запускай этот скрипт от обычного пользователя, не от root."
  exit 1
fi

readonly ANSI_RESET=$'\033[0m'
readonly ANSI_INFO=$'\033[1;38;5;151m'
readonly ANSI_DONE=$'\033[1;38;5;114m'
readonly ANSI_WARN=$'\033[1;38;5;221m'
readonly ANSI_ERROR=$'\033[1;38;5;203m'

info() {
  printf "\n%s[INFO]%s %s\n" "${ANSI_INFO}" "${ANSI_RESET}" "$1"
}

done_msg() {
  printf "%s[OK]%s %s\n" "${ANSI_DONE}" "${ANSI_RESET}" "$1"
}

warn() {
  printf "%s[WARN]%s %s\n" "${ANSI_WARN}" "${ANSI_RESET}" "$1"
}

die() {
  printf "%s[ERROR]%s %s\n" "${ANSI_ERROR}" "${ANSI_RESET}" "$1" >&2
  exit 1
}

backup_if_exists() {
  local target="$1"

  if [[ -e "${target}" ]]; then
    cp -r "${target}" "${target}.bak.$(date +%s)"
  fi
}

USER_NAME="${SUDO_USER:-$USER}"
USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"

[[ -n "${USER_HOME}" ]] || die "Не удалось определить домашнюю директорию пользователя ${USER_NAME}."

readonly CONFIG_DIR="${USER_HOME}/.config"
readonly LOCAL_BIN="${USER_HOME}/.local/bin"
readonly WALL_DIR="${USER_HOME}/Pictures/Wallpapers"
readonly WALLPAPER="${WALL_DIR}/wallpaper.jpg"

BATTERY_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "${d}/type" ]] && grep -qx 'Battery' "${d}/type" && basename "${d}" && break
done || true)"
AC_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "${d}/type" ]] && grep -Eqx 'Mains|USB|USB_C|USB_PD' "${d}/type" && basename "${d}" && break
done || true)"

BATTERY_NAME="${BATTERY_NAME:-BAT0}"
AC_NAME="${AC_NAME:-AC}"

POLYBAR_RIGHT_MODULES="updates cpu memory pulseaudio network bluetooth date control power"
if [[ -d "/sys/class/power_supply/${BATTERY_NAME}" ]]; then
  POLYBAR_RIGHT_MODULES="updates cpu memory pulseaudio network bluetooth battery date control power"
fi

PACKAGES=(
  alacritty
  arandr
  blueman
  bluez
  bluez-utils
  bspwm
  dbus
  dunst
  fastfetch
  feh
  firefox
  i3lock
  libnotify
  lxappearance
  network-manager-applet
  networkmanager
  noto-fonts
  noto-fonts-emoji
  pacman-contrib
  papirus-icon-theme
  pavucontrol
  picom
  pipewire
  pipewire-pulse
  polybar
  rofi
  sxhkd
  thunar
  ttf-jetbrains-mono-nerd
  wireplumber
  xdotool
  xorg-server
  xorg-xinit
  xorg-xrandr
  xorg-xsetroot
  xss-lock
  yad
)

BACKUP_TARGETS=(
  "${CONFIG_DIR}/alacritty/alacritty.toml"
  "${CONFIG_DIR}/bspwm/bspwmrc"
  "${CONFIG_DIR}/dunst/dunstrc"
  "${CONFIG_DIR}/gtk-3.0/settings.ini"
  "${CONFIG_DIR}/gtk-4.0/settings.ini"
  "${CONFIG_DIR}/picom/picom.conf"
  "${CONFIG_DIR}/polybar/config.ini"
  "${CONFIG_DIR}/polybar/scripts/network-status"
  "${CONFIG_DIR}/polybar/scripts/bluetooth-status"
  "${CONFIG_DIR}/polybar/scripts/updates-status"
  "${CONFIG_DIR}/rofi/config.rasi"
  "${CONFIG_DIR}/rofi/launcher.rasi"
  "${CONFIG_DIR}/rofi/menu.rasi"
  "${CONFIG_DIR}/sxhkd/sxhkdrc"
  "${LOCAL_BIN}/app-settings"
  "${LOCAL_BIN}/control-center"
  "${LOCAL_BIN}/dropdown-terminal"
  "${LOCAL_BIN}/lock-screen"
  "${LOCAL_BIN}/open-app-launcher"
  "${LOCAL_BIN}/power-menu"
  "${LOCAL_BIN}/system-settings"
  "${LOCAL_BIN}/update-system"
  "${USER_HOME}/.bash_profile"
  "${USER_HOME}/.bashrc"
  "${USER_HOME}/.xinitrc"
  "${USER_HOME}/.xprofile"
)

create_directories() {
  mkdir -p \
    "${CONFIG_DIR}/alacritty" \
    "${CONFIG_DIR}/bspwm" \
    "${CONFIG_DIR}/dunst" \
    "${CONFIG_DIR}/gtk-3.0" \
    "${CONFIG_DIR}/gtk-4.0" \
    "${CONFIG_DIR}/picom" \
    "${CONFIG_DIR}/polybar/scripts" \
    "${CONFIG_DIR}/rofi" \
    "${CONFIG_DIR}/sxhkd" \
    "${LOCAL_BIN}" \
    "${WALL_DIR}"
}

backup_existing_files() {
  local target

  for target in "${BACKUP_TARGETS[@]}"; do
    backup_if_exists "${target}"
  done
}

install_packages() {
  info "Обновление системы и установка пакетов"
  sudo pacman -Syu --needed --noconfirm "${PACKAGES[@]}"
  done_msg "Пакеты установлены."
}

enable_services() {
  info "Включение системных сервисов"
  sudo systemctl enable NetworkManager
  sudo systemctl enable bluetooth
  sudo systemctl enable wireplumber
  done_msg "Сервисы активированы."
}

write_lock_screen() {
  cat > "${LOCAL_BIN}/lock-screen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec i3lock -n -c 101418
EOF

  chmod +x "${LOCAL_BIN}/lock-screen"
}

write_dropdown_terminal() {
  cat > "${LOCAL_BIN}/dropdown-terminal" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

position_dropdown() {
  local wid="$1"
  local screen sw sh ww wh wx wy

  screen="$(xrandr | awk '/\*/ {print $1; exit}')"
  sw="${screen%x*}"
  sh="${screen#*x}"

  ww=$(( sw * 76 / 100 ))
  wh=$(( sh * 68 / 100 ))
  wx=$(( (sw - ww) / 2 ))
  wy=42

  xdotool windowsize "${wid}" "${ww}" "${wh}"
  xdotool windowmove "${wid}" "${wx}" "${wy}"
}

existing_id="$(xdotool search --class dropdown 2>/dev/null | tail -n 1 || true)"

if [[ -n "${existing_id}" ]]; then
  xdotool windowmap "${existing_id}" >/dev/null 2>&1 || true
  position_dropdown "${existing_id}"
  xdotool windowactivate "${existing_id}" >/dev/null 2>&1 || true
  exit 0
fi

alacritty --class dropdown &
sleep 0.35

wid="$(xdotool search --sync --onlyvisible --class dropdown | tail -n 1)"
position_dropdown "${wid}"
EOF

  chmod +x "${LOCAL_BIN}/dropdown-terminal"
}

write_update_script() {
  cat > "${LOCAL_BIN}/update-system" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec alacritty --class settings-editor -e bash -lc 'sudo pacman -Syu; echo; read -n 1 -s -r -p "Нажми любую клавишу для закрытия..."'
EOF

  chmod +x "${LOCAL_BIN}/update-system"
}

write_launcher_script() {
  cat > "${LOCAL_BIN}/open-app-launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec rofi -show drun -theme "$HOME/.config/rofi/launcher.rasi"
EOF

  chmod +x "${LOCAL_BIN}/open-app-launcher"
}

write_control_center_script() {
  cat > "${LOCAL_BIN}/control-center" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

choice="$(
  printf '%s\n' \
    '󰀻  Запуск приложений' \
    '󰛳  Настройки приложений' \
    '󰒓  Системные настройки' \
    '󰏗  Обновить систему' \
    '󰐥  Меню питания' |
    rofi -dmenu -i -p "hub" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "󰀻  Запуск приложений") exec "$HOME/.local/bin/open-app-launcher" ;;
  "󰛳  Настройки приложений") exec "$HOME/.local/bin/app-settings" ;;
  "󰒓  Системные настройки") exec "$HOME/.local/bin/system-settings" ;;
  "󰏗  Обновить систему") exec "$HOME/.local/bin/update-system" ;;
  "󰐥  Меню питания") exec "$HOME/.local/bin/power-menu" ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/control-center"
}

write_power_menu_script() {
  cat > "${LOCAL_BIN}/power-menu" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

choice="$(
  printf '%s\n' \
    '󰍃  Заблокировать' \
    '󰤄  Сон' \
    '󰜉  Перезагрузить' \
    '󰐥  Выключить' \
    '󰗼  Выйти из bspwm' |
    rofi -dmenu -i -p "power" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "󰍃  Заблокировать") exec "$HOME/.local/bin/lock-screen" ;;
  "󰤄  Сон") systemctl suspend ;;
  "󰜉  Перезагрузить") systemctl reboot ;;
  "󰐥  Выключить") systemctl poweroff ;;
  "󰗼  Выйти из bspwm") bspc quit ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/power-menu"
}

write_app_settings_script() {
  cat > "${LOCAL_BIN}/app-settings" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

open_terminal_editor() {
  local file="$1"

  exec alacritty --class settings-editor -e bash -lc "editor=\${EDITOR:-nano}; command -v \"\$editor\" >/dev/null 2>&1 || editor=vi; exec \"\$editor\" \"${file}\""
}

open_target() {
  case "$1" in
    firefox) exec firefox --new-window about:preferences ;;
    terminal) open_terminal_editor "$HOME/.config/alacritty/alacritty.toml" ;;
    panel) open_terminal_editor "$HOME/.config/polybar/config.ini" ;;
    launcher) open_terminal_editor "$HOME/.config/rofi/launcher.rasi" ;;
    notifications) open_terminal_editor "$HOME/.config/dunst/dunstrc" ;;
    compositor) open_terminal_editor "$HOME/.config/picom/picom.conf" ;;
    files) exec thunar --preferences ;;
    *) exit 0 ;;
  esac
}

if [[ $# -gt 0 ]]; then
  open_target "$1"
fi

choice="$(
  yad \
    --class=AppDeckSettings \
    --title="Настройки приложений" \
    --window-icon="applications-system" \
    --center \
    --width=760 \
    --height=420 \
    --list \
    --separator="|" \
    --column="Раздел" \
    --column="Что откроется" \
    "Firefox" "about:preferences, стартовая страница и приватность" \
    "Alacritty" "Конфиг прозрачности, шрифта и цветов" \
    "Polybar" "Главный конфиг информативного хедбара" \
    "Rofi Launcher" "Сетка приложений и quick hub" \
    "Dunst" "Уведомления и их оформление" \
    "Picom" "Сглаживание, тени и плавность" \
    "Thunar" "Настройки файлового менеджера" \
    --button="Открыть:0" \
    --button="Закрыть:1" || true
)"

selection="${choice%%|*}"

case "${selection}" in
  Firefox) open_target firefox ;;
  Alacritty) open_target terminal ;;
  Polybar) open_target panel ;;
  "Rofi Launcher") open_target launcher ;;
  Dunst) open_target notifications ;;
  Picom) open_target compositor ;;
  Thunar) open_target files ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/app-settings"
}

write_system_settings_script() {
  cat > "${LOCAL_BIN}/system-settings" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

open_target() {
  case "$1" in
    network) exec nm-connection-editor ;;
    bluetooth) exec blueman-manager ;;
    audio) exec pavucontrol ;;
    display) exec arandr ;;
    appearance) exec lxappearance ;;
    updates) exec "$HOME/.local/bin/update-system" ;;
    power) exec "$HOME/.local/bin/power-menu" ;;
    *) exit 0 ;;
  esac
}

if [[ $# -gt 0 ]]; then
  open_target "$1"
fi

choice="$(
  yad \
    --class=SystemDeckSettings \
    --title="Системные настройки" \
    --window-icon="preferences-desktop" \
    --center \
    --width=780 \
    --height=440 \
    --list \
    --separator="|" \
    --column="Раздел" \
    --column="Что откроется" \
    "Сеть" "Wi-Fi, Ethernet, VPN и точки доступа" \
    "Bluetooth" "Подключение наушников, мышек и других устройств" \
    "Звук" "Выходы, входы и уровни громкости" \
    "Мониторы" "Положение экранов и разрешение" \
    "Внешний вид" "GTK-тема, иконки, курсор и шрифты" \
    "Обновления" "Полное обновление Arch-системы" \
    "Питание" "Lock, suspend, reboot и shutdown" \
    --button="Открыть:0" \
    --button="Закрыть:1" || true
)"

selection="${choice%%|*}"

case "${selection}" in
  Сеть) open_target network ;;
  Bluetooth) open_target bluetooth ;;
  Звук) open_target audio ;;
  Мониторы) open_target display ;;
  "Внешний вид") open_target appearance ;;
  Обновления) open_target updates ;;
  Питание) open_target power ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/system-settings"
}

write_polybar_scripts() {
  cat > "${CONFIG_DIR}/polybar/scripts/network-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

trim_label() {
  local label="$1"
  local max_len=18

  if (( ${#label} > max_len )); then
    printf '%s…' "${label:0:max_len-1}"
  else
    printf '%s' "${label}"
  fi
}

active_wifi="$(
  nmcli -t -f IN-USE,SIGNAL,SSID dev wifi 2>/dev/null |
    awk -F: '$1=="*" {print $2 "|" $3; exit}' || true
)"
wired_state="$(
  nmcli -t -f TYPE,STATE dev status 2>/dev/null |
    awk -F: '$1=="ethernet" && $2=="connected" {print "yes"; exit}' || true
)"

if [[ -n "${active_wifi}" ]]; then
  signal="${active_wifi%%|*}"
  ssid="${active_wifi#*|}"

  if (( signal >= 75 )); then
    icon="󰤨"
  elif (( signal >= 50 )); then
    icon="󰤥"
  elif (( signal >= 25 )); then
    icon="󰤢"
  else
    icon="󰤟"
  fi

  printf '%s %s\n' "${icon}" "$(trim_label "${ssid}")"
  exit 0
fi

if [[ "${wired_state:-no}" == "yes" ]]; then
  printf '󰈀 wired\n'
  exit 0
fi

printf '󰤮 offline\n'
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/bluetooth-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

trim_label() {
  local label="$1"
  local max_len=16

  if (( ${#label} > max_len )); then
    printf '%s…' "${label:0:max_len-1}"
  else
    printf '%s' "${label}"
  fi
}

powered="$(
  bluetoothctl show 2>/dev/null |
    awk -F': ' '/Powered:/ {print $2; exit}' || true
)"

if [[ "${powered:-no}" != "yes" ]]; then
  printf '󰂲 off\n'
  exit 0
fi

device="$(
  bluetoothctl devices Connected 2>/dev/null |
    head -n 1 |
    cut -d' ' -f3- || true
)"

if [[ -n "${device}" ]]; then
  printf '󰂱 %s\n' "$(trim_label "${device}")"
  exit 0
fi

printf '󰂯 ready\n'
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/updates-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v checkupdates >/dev/null 2>&1; then
  printf '󰄬 fresh\n'
  exit 0
fi

count="$(checkupdates 2>/dev/null | wc -l | tr -d ' ' || true)"

if [[ -z "${count}" || "${count}" == "0" ]]; then
  printf '󰄬 fresh\n'
  exit 0
fi

printf '󰏗 %s\n' "${count}"
EOF

  chmod +x \
    "${CONFIG_DIR}/polybar/scripts/network-status" \
    "${CONFIG_DIR}/polybar/scripts/bluetooth-status" \
    "${CONFIG_DIR}/polybar/scripts/updates-status"
}

write_bspwm_config() {
  cat > "${CONFIG_DIR}/bspwm/bspwmrc" <<'EOF'
#!/usr/bin/env bash

pgrep -x sxhkd >/dev/null || sxhkd &
pgrep -x picom >/dev/null || picom --config "$HOME/.config/picom/picom.conf" &
pgrep -x dunst >/dev/null || dunst &
pgrep -x xss-lock >/dev/null || xss-lock --transfer-sleep-lock -- "$HOME/.local/bin/lock-screen" &

pkill polybar >/dev/null 2>&1 || true
polybar main >/tmp/polybar-main.log 2>&1 &

xsetroot -cursor_name left_ptr

if [ -f "$HOME/Pictures/Wallpapers/wallpaper.jpg" ]; then
  feh --bg-fill "$HOME/Pictures/Wallpapers/wallpaper.jpg"
fi

bspc monitor -d I II III IV V VI VII VIII IX X

bspc config border_width 2
bspc config window_gap 18
bspc config split_ratio 0.52
bspc config borderless_monocle true
bspc config gapless_monocle true
bspc config focus_follows_pointer true
bspc config pointer_modifier mod1
bspc config focused_border_color "#79D0B8"
bspc config active_border_color "#F6C177"
bspc config normal_border_color "#2B343F"
bspc config presel_feedback_color "#F28FAD"

bspc rule -a dropdown state=floating sticky=on center=on layer=above
bspc rule -a settings-editor state=floating center=on
bspc rule -a AppDeckSettings state=floating center=on
bspc rule -a SystemDeckSettings state=floating center=on
bspc rule -a Nm-connection-editor state=floating center=on
bspc rule -a Blueman-manager state=floating center=on
bspc rule -a Pavucontrol state=floating center=on
bspc rule -a Lxappearance state=floating center=on
bspc rule -a Arandr state=floating center=on
EOF

  chmod +x "${CONFIG_DIR}/bspwm/bspwmrc"
}

write_sxhkd_config() {
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

# app deck
super + d
    ~/.local/bin/open-app-launcher

alt + d
    ~/.local/bin/open-app-launcher

# control center
super + c
    ~/.local/bin/control-center

alt + c
    ~/.local/bin/control-center

# system settings
super + s
    ~/.local/bin/system-settings

alt + s
    ~/.local/bin/system-settings

# app settings
super + comma
    ~/.local/bin/app-settings

alt + comma
    ~/.local/bin/app-settings

# power menu
super + shift + p
    ~/.local/bin/power-menu

alt + shift + p
    ~/.local/bin/power-menu

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
}

write_polybar_config() {
  cat > "${CONFIG_DIR}/polybar/config.ini" <<EOF
[colors]
background = #D9101418
surface = #F1161B21
surface-alt = #F11D252D
foreground = #F5F7FA
muted = #93A0AD
primary = #79D0B8
secondary = #F6C177
alert = #F28FAD
border = #2B343F
shadow = #00000000

[bar/main]
width = 96%
offset-x = 2%
offset-y = 12
height = 40
radius = 20
background = \${colors.background}
foreground = \${colors.foreground}
border-size = 1
border-color = \${colors.border}
padding-left = 2
padding-right = 2
module-margin = 1
separator =
wm-restack = bspwm
enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize
font-0 = JetBrainsMono Nerd Font:size=10;2
font-1 = Noto Color Emoji:size=10;1
modules-left = launcher bspwm
modules-center = xwindow
modules-right = ${POLYBAR_RIGHT_MODULES}

[module/base]
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2

[module/launcher]
type = custom/text
content = 󰣇
content-background = \${colors.surface-alt}
content-foreground = \${colors.primary}
content-padding = 2
click-left = ~/.local/bin/open-app-launcher
click-right = ~/.local/bin/control-center

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
enable-click = true
enable-scroll = false
label-focused = %name%
label-focused-background = \${colors.primary}
label-focused-foreground = #101418
label-focused-padding = 2
label-focused-margin = 1
label-occupied = %name%
label-occupied-background = \${colors.surface}
label-occupied-foreground = \${colors.foreground}
label-occupied-padding = 2
label-occupied-margin = 1
label-empty = %name%
label-empty-background = \${colors.surface}
label-empty-foreground = \${colors.muted}
label-empty-padding = 2
label-empty-margin = 1
label-urgent = %name%
label-urgent-background = \${colors.alert}
label-urgent-foreground = #101418
label-urgent-padding = 2
label-urgent-margin = 1

[module/xwindow]
type = internal/xwindow
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
label = %title:0:54:...%
label-empty = desktop lounge
label-empty-foreground = \${colors.muted}

[module/updates]
type = custom/script
exec = ~/.config/polybar/scripts/updates-status
interval = 600
format-background = \${colors.surface}
format-foreground = \${colors.secondary}
format-padding = 2
click-left = ~/.local/bin/update-system
click-right = ~/.local/bin/control-center

[module/cpu]
type = internal/cpu
interval = 2
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
label = 󰍛 %percentage%%

[module/memory]
type = internal/memory
interval = 5
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
label = 󰘚 %percentage_used%%

[module/pulseaudio]
type = internal/pulseaudio
format-volume-background = \${colors.surface}
format-volume-foreground = \${colors.foreground}
format-volume-padding = 2
format-muted-background = \${colors.surface}
format-muted-foreground = \${colors.muted}
format-muted-padding = 2
label-volume = 󰕾 %percentage%%
label-muted = 󰝟 mute
click-right = pavucontrol

[module/network]
type = custom/script
exec = ~/.config/polybar/scripts/network-status
interval = 5
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
click-left = ~/.local/bin/system-settings network
click-right = nm-connection-editor

[module/bluetooth]
type = custom/script
exec = ~/.config/polybar/scripts/bluetooth-status
interval = 8
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
click-left = ~/.local/bin/system-settings bluetooth
click-right = blueman-manager

[module/battery]
type = internal/battery
battery = ${BATTERY_NAME}
adapter = ${AC_NAME}
full-at = 99
poll-interval = 5
format-charging-background = \${colors.surface}
format-charging-foreground = \${colors.foreground}
format-charging-padding = 2
format-discharging-background = \${colors.surface}
format-discharging-foreground = \${colors.foreground}
format-discharging-padding = 2
format-full-background = \${colors.surface}
format-full-foreground = \${colors.foreground}
format-full-padding = 2
format-charging = 󰂄 <label-charging>
format-discharging = <ramp-capacity> <label-discharging>
format-full = 󰁹 <label-full>
label-charging = %percentage%%
label-discharging = %percentage%%
label-full = 100%%
ramp-capacity-0 = 󰂎
ramp-capacity-1 = 󰁺
ramp-capacity-2 = 󰁼
ramp-capacity-3 = 󰁾
ramp-capacity-4 = 󰂀
ramp-capacity-5 = 󰁹

[module/date]
type = internal/date
interval = 5
date = %a %d %b
time = %H:%M
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2
label = 󰃭 %time%  %date%

[module/control]
type = custom/text
content = 󰒓
content-background = \${colors.surface-alt}
content-foreground = \${colors.secondary}
content-padding = 2
click-left = ~/.local/bin/control-center
click-right = ~/.local/bin/system-settings

[module/power]
type = custom/text
content = 󰐥
content-background = \${colors.surface-alt}
content-foreground = \${colors.alert}
content-padding = 2
click-left = ~/.local/bin/power-menu
click-right = ~/.local/bin/lock-screen
EOF
}

write_alacritty_config() {
  cat > "${CONFIG_DIR}/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.9
padding = { x = 16, y = 14 }
decorations = "None"
dynamic_padding = true

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size = 11.0

[cursor]
blink_interval = 600

[cursor.style]
shape = "Beam"
blinking = "On"

[selection]
save_to_clipboard = true

[colors.primary]
background = "#101418"
foreground = "#F5F7FA"

[colors.cursor]
text = "#101418"
cursor = "#79D0B8"

[colors.normal]
black = "#161B21"
red = "#F28FAD"
green = "#79D0B8"
yellow = "#F6C177"
blue = "#8FB9FF"
magenta = "#D8A7FF"
cyan = "#7DD3FC"
white = "#D5DDE5"

[colors.bright]
black = "#566170"
red = "#FF9EBA"
green = "#8AE2C8"
yellow = "#FFD08A"
blue = "#A5C9FF"
magenta = "#E4B9FF"
cyan = "#A4E7FF"
white = "#F5F7FA"
EOF
}

write_picom_config() {
  cat > "${CONFIG_DIR}/picom/picom.conf" <<'EOF'
backend = "glx";
vsync = true;
use-damage = true;

shadow = true;
shadow-radius = 28;
shadow-opacity = 0.24;
shadow-offset-x = -14;
shadow-offset-y = -14;
shadow-exclude = [
  "class_g = 'Polybar'",
  "window_type = 'dock'"
];

fading = true;
fade-delta = 8;
fade-in-step = 0.035;
fade-out-step = 0.035;

inactive-opacity = 0.95;
active-opacity = 1.0;
frame-opacity = 1.0;
inactive-dim = 0.05;

corner-radius = 18;
detect-rounded-corners = true;
blur-method = "dual_kawase";
blur-strength = 8;
blur-background-exclude = [
  "class_g = 'Polybar'",
  "window_type = 'dock'"
];

mark-wmwin-focused = true;
mark-ovredir-focused = true;
detect-client-opacity = true;

wintypes:
{
  dock = { shadow = false; clip-shadow-above = true; };
  tooltip = { fade = true; shadow = true; opacity = 0.96; focus = true; };
  dropdown_menu = { opacity = 0.98; };
  popup_menu = { opacity = 0.98; };
};

opacity-rule = [
  "92:class_g = 'Alacritty'",
  "94:class_g = 'dropdown'",
  "96:class_g = 'Rofi'",
  "98:class_g = 'AppDeckSettings'",
  "98:class_g = 'SystemDeckSettings'"
];
EOF
}

write_dunst_config() {
  cat > "${CONFIG_DIR}/dunst/dunstrc" <<'EOF'
[global]
    monitor = 0
    follow = keyboard
    width = 380
    height = 110
    origin = top-right
    offset = 18x62
    corner_radius = 16
    frame_width = 2
    gap_size = 10
    font = JetBrainsMono Nerd Font 10
    icon_theme = Papirus-Dark
    enable_recursive_icon_lookup = true
    background = "#101418"
    foreground = "#F5F7FA"
    frame_color = "#79D0B8"
    separator_color = frame
    timeout = 6
    markup = full
    format = "<b>%s</b>\n%b"

[urgency_low]
    background = "#101418"
    foreground = "#F5F7FA"
    frame_color = "#2B343F"

[urgency_normal]
    background = "#101418"
    foreground = "#F5F7FA"
    frame_color = "#79D0B8"

[urgency_critical]
    background = "#101418"
    foreground = "#F5F7FA"
    frame_color = "#F28FAD"
    timeout = 0
EOF
}

write_rofi_config() {
  cat > "${CONFIG_DIR}/rofi/config.rasi" <<'EOF'
configuration {
  modi: "drun,run,window";
  font: "JetBrainsMono Nerd Font 11";
  show-icons: true;
  icon-theme: "Papirus-Dark";
  drun-display-format: "{name}";
  disable-history: false;
  hover-select: true;
  display-drun: "apps";
  display-run: "run";
  display-window: "windows";
}
EOF

  cat > "${CONFIG_DIR}/rofi/launcher.rasi" <<'EOF'
@import "~/.config/rofi/config.rasi"

* {
  bg: #0f1418ee;
  bg-panel: #161b21ff;
  bg-card: #1d252dff;
  fg: #f5f7faff;
  muted: #93a0adff;
  accent: #79d0b8ff;
  border: #2b343fff;
  urgent: #f28fadff;
  radius: 22px;
  spacing: 14px;
}

window {
  width: 46%;
  border: 1px;
  border-color: @border;
  border-radius: @radius;
  background-color: @bg;
  location: center;
  anchor: center;
}

mainbox {
  spacing: 18px;
  padding: 22px;
  background-color: transparent;
}

inputbar {
  children: [ prompt, entry ];
  spacing: 12px;
  padding: 16px 18px;
  border: 0px;
  border-radius: 18px;
  background-color: @bg-panel;
}

prompt {
  enabled: true;
  text-color: @accent;
  background-color: transparent;
}

entry {
  placeholder: "Запусти то, что хочется";
  placeholder-color: @muted;
  text-color: @fg;
  background-color: transparent;
}

listview {
  columns: 2;
  lines: 5;
  spacing: @spacing;
  cycle: false;
  scrollbar: false;
  dynamic: true;
  background-color: transparent;
}

element {
  orientation: vertical;
  spacing: 12px;
  padding: 18px 16px;
  border-radius: 18px;
  background-color: @bg-card;
  text-color: @fg;
}

element selected {
  background-color: @accent;
  text-color: #101418ff;
}

element-icon {
  size: 46px;
  horizontal-align: 0.5;
  vertical-align: 0.5;
  background-color: transparent;
}

element-text {
  horizontal-align: 0.5;
  vertical-align: 0.5;
  background-color: transparent;
  text-color: inherit;
}
EOF

  cat > "${CONFIG_DIR}/rofi/menu.rasi" <<'EOF'
@import "~/.config/rofi/config.rasi"

* {
  bg: #101418ee;
  bg-panel: #161b21ff;
  bg-card: #1d252dff;
  fg: #f5f7faff;
  muted: #93a0adff;
  accent: #f6c177ff;
  border: #2b343fff;
  radius: 20px;
}

window {
  width: 28%;
  border: 1px;
  border-color: @border;
  border-radius: @radius;
  background-color: @bg;
  location: center;
  anchor: center;
}

mainbox {
  spacing: 16px;
  padding: 18px;
  background-color: transparent;
}

inputbar {
  children: [ prompt, entry ];
  spacing: 10px;
  padding: 14px 16px;
  border: 0px;
  border-radius: 16px;
  background-color: @bg-panel;
}

prompt {
  enabled: true;
  text-color: @accent;
  background-color: transparent;
}

entry {
  placeholder: "Быстрые действия";
  placeholder-color: @muted;
  text-color: @fg;
  background-color: transparent;
}

listview {
  columns: 1;
  lines: 6;
  spacing: 10px;
  cycle: false;
  scrollbar: false;
  background-color: transparent;
}

element {
  padding: 14px 16px;
  border-radius: 16px;
  background-color: @bg-card;
  text-color: @fg;
}

element selected {
  background-color: @accent;
  text-color: #101418ff;
}

element-text {
  background-color: transparent;
  text-color: inherit;
}
EOF
}

write_gtk_config() {
  cat > "${CONFIG_DIR}/gtk-3.0/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
gtk-toolbar-style=GTK_TOOLBAR_ICONS
gtk-button-images=0
gtk-menu-images=0
EOF

  cat > "${CONFIG_DIR}/gtk-4.0/settings.ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=JetBrainsMono Nerd Font 10
gtk-cursor-theme-name=Adwaita
gtk-cursor-theme-size=24
EOF
}

write_x_profile() {
  cat > "${USER_HOME}/.xprofile" <<'EOF'
export GTK_THEME=Adwaita:dark
export XCURSOR_SIZE=24
export BROWSER=firefox
EOF
}

write_x_session() {
  cat > "${USER_HOME}/.xinitrc" <<'EOF'
#!/usr/bin/env bash

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
}

configure_autologin() {
  info "Автологин в tty1 и systemd reload"

  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  cat <<EOF | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER_NAME} --noclear %I \$TERM
EOF

  sudo systemctl daemon-reload
  done_msg "Автологин настроен."
}

append_fastfetch() {
  if grep -q "fastfetch" "${USER_HOME}/.bashrc" 2>/dev/null; then
    warn "fastfetch уже прописан в .bashrc, пропускаю."
    return 1
  fi

  cat >> "${USER_HOME}/.bashrc" <<'EOF'

if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi
EOF
}

fix_permissions() {
  sudo chown -R "${USER_NAME}:${USER_NAME}" \
    "${CONFIG_DIR}/alacritty" \
    "${CONFIG_DIR}/bspwm" \
    "${CONFIG_DIR}/dunst" \
    "${CONFIG_DIR}/gtk-3.0" \
    "${CONFIG_DIR}/gtk-4.0" \
    "${CONFIG_DIR}/picom" \
    "${CONFIG_DIR}/polybar" \
    "${CONFIG_DIR}/rofi" \
    "${CONFIG_DIR}/sxhkd" \
    "${LOCAL_BIN}" \
    "${WALL_DIR}" \
    "${USER_HOME}/.bash_profile" \
    "${USER_HOME}/.bashrc" \
    "${USER_HOME}/.xinitrc" \
    "${USER_HOME}/.xprofile"
}

print_next_steps() {
  echo
  printf "%sГотово.%s Рабочий стол теперь будет выглядеть заметно богаче.\n" "${ANSI_DONE}" "${ANSI_RESET}"
  echo
  echo "Что осталось:"
  echo "1. Положи обои сюда:"
  echo "   ${WALLPAPER}"
  echo
  echo "2. Перезагрузи систему:"
  echo "   sudo reboot"
  echo
  echo "3. Главные хоткеи:"
  echo "   Alt+Return         -> dropdown-терминал"
  echo "   Alt+Shift+Return   -> обычный терминал"
  echo "   Alt+d              -> App Deck / выбор приложений"
  echo "   Alt+c              -> quick hub"
  echo "   Alt+s              -> системные настройки"
  echo "   Alt+,              -> настройки приложений"
  echo "   Alt+Shift+p        -> меню питания"
  echo "   Alt+b              -> Firefox"
  echo "   Alt+e              -> Thunar"
  echo "   Alt+q              -> закрыть окно"
  echo "   Alt+Shift+l        -> блокировка экрана"
  echo "   Alt+Shift+u        -> обновление системы"
  echo
  echo "Верхняя панель теперь показывает обновления, CPU, RAM, звук, сеть, Bluetooth, батарею и время."
  echo "Обычный выход из bspwm хоткеями отключён. Аварийный доступ оставлен через Ctrl+Alt+F2."
}

main() {
  info "Создание директорий"
  create_directories
  done_msg "Папки готовы."

  info "Бэкап текущих конфигов"
  backup_existing_files
  done_msg "Бэкапы сохранены."

  install_packages
  enable_services

  info "Генерация helper-скриптов и конфигов"
  write_lock_screen
  write_dropdown_terminal
  write_update_script
  write_launcher_script
  write_control_center_script
  write_power_menu_script
  write_app_settings_script
  write_system_settings_script
  write_polybar_scripts
  write_bspwm_config
  write_sxhkd_config
  write_polybar_config
  write_alacritty_config
  write_picom_config
  write_dunst_config
  write_rofi_config
  write_gtk_config
  write_x_profile
  write_x_session
  done_msg "Новая тема и окружение записаны."

  configure_autologin

  info "fastfetch в bashrc"
  if append_fastfetch; then
    done_msg "fastfetch подключён."
  fi

  info "Права владельца"
  fix_permissions
  done_msg "Владельцы файлов выровнены."

  print_next_steps
}

main "$@"
