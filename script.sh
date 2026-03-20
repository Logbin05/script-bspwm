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

POLYBAR_RIGHT_MODULES="current-desktop updates pulseaudio network bluetooth date tray control power"
if [[ -d "/sys/class/power_supply/${BATTERY_NAME}" ]]; then
  POLYBAR_RIGHT_MODULES="current-desktop updates pulseaudio network bluetooth battery date tray control power"
fi

PACKAGES=(
  accountsservice
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
  libnotify
  light-locker
  lightdm
  lightdm-slick-greeter
  lxappearance
  network-manager-applet
  networkmanager
  noto-fonts
  noto-fonts-emoji
  openssh
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
  "${CONFIG_DIR}/polybar/user.ini"
  "${CONFIG_DIR}/polybar/scripts/network-status"
  "${CONFIG_DIR}/polybar/scripts/bluetooth-status"
  "${CONFIG_DIR}/polybar/scripts/current-desktop-status"
  "${CONFIG_DIR}/polybar/scripts/updates-status"
  "${CONFIG_DIR}/rofi/config.rasi"
  "${CONFIG_DIR}/rofi/launcher.rasi"
  "${CONFIG_DIR}/rofi/menu.rasi"
  "${CONFIG_DIR}/sxhkd/sxhkdrc"
  "${LOCAL_BIN}/app-settings"
  "${LOCAL_BIN}/arch-access"
  "${LOCAL_BIN}/bar-context-menu"
  "${LOCAL_BIN}/control-center"
  "${LOCAL_BIN}/dropdown-terminal"
  "${LOCAL_BIN}/launch-polybar"
  "${LOCAL_BIN}/lock-screen"
  "${LOCAL_BIN}/open-app-launcher"
  "${LOCAL_BIN}/power-menu"
  "${LOCAL_BIN}/polybar-preset"
  "${LOCAL_BIN}/bind-ssh-key"
  "${LOCAL_BIN}/set-user-avatar"
  "${LOCAL_BIN}/system-settings"
  "${LOCAL_BIN}/update-system"
  "${USER_HOME}/.ssh/config"
  "${USER_HOME}/.bash_profile"
  "${USER_HOME}/.bashrc"
  "${USER_HOME}/.xinitrc"
  "${USER_HOME}/.xprofile"
)

create_directories() {
  mkdir -p \
    "${CONFIG_DIR}/systemd/user/sockets.target.wants" \
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
    "${USER_HOME}/.ssh" \
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
  done_msg "Сервисы активированы."
}

write_lock_screen() {
  cat > "${LOCAL_BIN}/lock-screen" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if command -v light-locker-command >/dev/null 2>&1; then
  exec light-locker-command -l
fi

if command -v dm-tool >/dev/null 2>&1; then
  exec dm-tool switch-to-greeter
fi

printf 'Не найден light-locker или dm-tool.\n' >&2
exit 1
EOF

  chmod +x "${LOCAL_BIN}/lock-screen"
}

write_dropdown_terminal() {
  cat > "${LOCAL_BIN}/dropdown-terminal" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec alacritty
EOF

  chmod +x "${LOCAL_BIN}/dropdown-terminal"
}

write_launch_polybar_script() {
  cat > "${LOCAL_BIN}/launch-polybar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_dir="${HOME}/.cache/polybar"
log_file="${log_dir}/main.log"
config_file="${HOME}/.config/polybar/config.ini"

mkdir -p "${log_dir}"

if ! command -v polybar >/dev/null 2>&1; then
  printf '[%s] polybar command not found\n' "$(date +'%F %T')" >> "${log_file}"
  exit 1
fi

if [[ ! -f "${config_file}" ]]; then
  printf '[%s] config not found: %s\n' "$(date +'%F %T')" "${config_file}" >> "${log_file}"
  exit 1
fi

pkill polybar >/dev/null 2>&1 || true
polybar main -c "${config_file}" >> "${log_file}" 2>&1 &
EOF

  chmod +x "${LOCAL_BIN}/launch-polybar"
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

write_arch_access_script() {
  cat > "${LOCAL_BIN}/arch-access" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

print_help() {
  cat <<'USAGE'
Использование: arch-access [путь]

- Без аргументов покажет быстрый выбор пути через rofi (или запрос в терминале).
- Если путь указывает на папку, откроется root-shell в этой директории.
- Если путь указывает на файл, откроется sudoedit через твой EDITOR.
USAGE
}

pick_target() {
  local target=""

  if command -v rofi >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    target="$(
      printf '%s\n' \
        '/etc/' \
        '/etc/pacman.conf' \
        '/etc/ssh/sshd_config' \
        '/var/log/' \
        '/root/' \
        '/usr/local/etc/' |
        rofi -dmenu -i -p "arch-access path" -theme "$HOME/.config/rofi/menu.rasi" || true
    )"
  else
    printf 'Введи путь для arch-access: ' >&2
    read -r target || true
  fi

  printf '%s' "${target}"
}

normalize_target() {
  local raw="$1"

  raw="${raw/#\~/$HOME}"
  if [[ "${raw}" != /* ]]; then
    raw="$(realpath -m "$PWD/$raw")"
  fi

  printf '%s' "${raw}"
}

open_privileged_target() {
  local target="$1"

  if [[ -d "${target}" ]]; then
    exec alacritty --class settings-editor -e sudo -E env ARCH_ACCESS_DIR="${target}" bash -lc '
cd "$ARCH_ACCESS_DIR" || exit 1
printf "arch-access: root-shell in %s\n" "$ARCH_ACCESS_DIR"
exec ${SHELL:-bash} -l
'
  fi

  exec alacritty --class settings-editor -e env ARCH_ACCESS_FILE="${target}" bash -lc '
editor="${EDITOR:-nano}"
command -v "$editor" >/dev/null 2>&1 || editor=vi
export EDITOR="$editor"
exec sudoedit "$ARCH_ACCESS_FILE"
'
}

arg="${1:-}"

case "${arg}" in
  -h|--help)
    print_help
    exit 0
    ;;
esac

if [[ -z "${arg}" ]]; then
  arg="$(pick_target)"
fi

[[ -n "${arg}" ]] || exit 0

target="$(normalize_target "${arg}")"
open_privileged_target "${target}"
EOF

  chmod +x "${LOCAL_BIN}/arch-access"
}

write_bar_context_menu_script() {
  cat > "${LOCAL_BIN}/bar-context-menu" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

choice="$(
  printf '%s\n' \
    '󰀻  Запуск приложений' \
    '󰛳  Настройки приложений' \
    '󰒓  Системные настройки' \
    '󰖟  Polybar preset' \
    '󰇚  Polybar custom' \
    '󱎓  Приватные файлы (arch-access)' \
    '󰈆  Перезапустить bar' \
    '󰏗  Обновить систему' \
    '󰐥  Меню питания' |
    rofi -dmenu -i -p "context" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "󰀻  Запуск приложений") exec "$HOME/.local/bin/open-app-launcher" ;;
  "󰛳  Настройки приложений") exec "$HOME/.local/bin/app-settings" ;;
  "󰒓  Системные настройки") exec "$HOME/.local/bin/system-settings" ;;
  "󰖟  Polybar preset") exec "$HOME/.local/bin/polybar-preset" ;;
  "󰇚  Polybar custom") exec "$HOME/.local/bin/app-settings" panel-custom ;;
  "󱎓  Приватные файлы (arch-access)") exec "$HOME/.local/bin/arch-access" ;;
  "󰈆  Перезапустить bar") exec "$HOME/.local/bin/launch-polybar" ;;
  "󰏗  Обновить систему") exec "$HOME/.local/bin/update-system" ;;
  "󰐥  Меню питания") exec "$HOME/.local/bin/power-menu" ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/bar-context-menu"
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
    '󱎓  Приватные файлы' \
    '󰏗  Обновить систему' \
    '󰐥  Меню питания' |
    rofi -dmenu -i -p "hub" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "󰀻  Запуск приложений") exec "$HOME/.local/bin/open-app-launcher" ;;
  "󰛳  Настройки приложений") exec "$HOME/.local/bin/app-settings" ;;
  "󰒓  Системные настройки") exec "$HOME/.local/bin/system-settings" ;;
  "󱎓  Приватные файлы") exec "$HOME/.local/bin/arch-access" ;;
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
  "󰤄  Сон")
    "$HOME/.local/bin/lock-screen"
    sleep 0.8
    systemctl suspend
    ;;
  "󰜉  Перезагрузить") systemctl reboot ;;
  "󰐥  Выключить") systemctl poweroff ;;
  "󰗼  Выйти из bspwm") bspc quit ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/power-menu"
}

write_avatar_script() {
  cat > "${LOCAL_BIN}/set-user-avatar" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

pick_avatar() {
  yad \
    --file \
    --title="Выбери аватар" \
    --file-filter="Images | *.png *.jpg *.jpeg *.webp *.bmp" || true
}

source_path="${1:-}"

if [[ -z "${source_path}" || "${source_path}" == "--pick" ]]; then
  source_path="$(pick_avatar)"
fi

[[ -n "${source_path:-}" ]] || exit 0
[[ -f "${source_path}" ]] || {
  printf 'Файл не найден: %s\n' "${source_path}" >&2
  exit 1
}

user_name="${SUDO_USER:-$USER}"
dest="/var/lib/AccountsService/icons/${user_name}"
account_file="/var/lib/AccountsService/users/${user_name}"

sudo install -d /var/lib/AccountsService/icons /var/lib/AccountsService/users
sudo install -m 644 "${source_path}" "${dest}"
sudo tee "${account_file}" >/dev/null <<EOF2
[User]
Icon=${dest}
EOF2
sudo chmod 644 "${dest}" "${account_file}"
install -Dm644 "${source_path}" "${HOME}/.face"

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  notify-send "Аватар обновлён" "Новая аватарка появится на экране блокировки."
fi
EOF

  chmod +x "${LOCAL_BIN}/set-user-avatar"
}

write_ssh_key_script() {
  cat > "${LOCAL_BIN}/bind-ssh-key" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${runtime_dir}/ssh-agent.socket}"

CONFIG_FILE="${HOME}/.ssh/config"
MARK_BEGIN="# >>> IMBA SSH BEGIN >>>"
MARK_END="# <<< IMBA SSH END <<<"

pick_key() {
  yad \
    --file \
    --title="Выбери SSH ключ" \
    --file-filter="SSH private keys | *" || true
}

detect_default_key() {
  local key

  for key in \
    "${HOME}/.ssh/id_ed25519" \
    "${HOME}/.ssh/id_rsa" \
    "${HOME}/.ssh/id_ecdsa" \
    "${HOME}/.ssh/id_ed25519_sk" \
    "${HOME}/.ssh/id_ecdsa_sk"; do
    [[ -f "${key}" ]] && printf '%s\n' "${key}" && return 0
  done

  return 1
}

key_path="${1:-}"

if [[ "${key_path}" == "--auto" ]]; then
  key_path="$(detect_default_key || true)"
elif [[ -z "${key_path}" || "${key_path}" == "--pick" ]]; then
  key_path="$(pick_key)"
fi

if [[ -n "${key_path}" && ! -f "${key_path}" ]]; then
  printf 'SSH ключ не найден: %s\n' "${key_path}" >&2
  exit 1
fi

mkdir -p "${HOME}/.ssh" "${HOME}/.config/systemd/user/sockets.target.wants"
chmod 700 "${HOME}/.ssh"

touch "${CONFIG_FILE}"
chmod 600 "${CONFIG_FILE}"

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

awk -v begin="${MARK_BEGIN}" -v end="${MARK_END}" '
  $0 == begin { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "${CONFIG_FILE}" > "${tmp_file}"

{
  cat "${tmp_file}"
  [[ -s "${tmp_file}" ]] && printf '\n'
  printf '%s\n' "${MARK_BEGIN}"
  printf '%s\n' "Host *"
  printf '%s\n' "  AddKeysToAgent yes"
  if [[ -n "${key_path}" ]]; then
    printf '  IdentityFile %s\n' "${key_path}"
  fi
  printf '%s\n' "${MARK_END}"
} > "${CONFIG_FILE}"

chmod 600 "${CONFIG_FILE}"

ln -sf /usr/lib/systemd/user/ssh-agent.socket \
  "${HOME}/.config/systemd/user/sockets.target.wants/ssh-agent.socket"

systemctl --user daemon-reload >/dev/null 2>&1 || true
systemctl --user enable --now ssh-agent.socket >/dev/null 2>&1 || true

if [[ -n "${key_path}" ]] && [[ -t 0 ]] && [[ -t 1 ]]; then
  ssh-add "${key_path}" </dev/tty || true
fi

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  if [[ -n "${key_path}" ]]; then
    notify-send "SSH ключ привязан" "Ключ ${key_path##*/} будет подхватываться через ssh-agent."
  else
    notify-send "SSH agent настроен" "Осталось выбрать ключ через ~/.local/bin/bind-ssh-key --pick."
  fi
fi
EOF

  chmod +x "${LOCAL_BIN}/bind-ssh-key"
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
    panel-custom) open_terminal_editor "$HOME/.config/polybar/user.ini" ;;
    panel-preset) exec "$HOME/.local/bin/polybar-preset" ;;
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
    "Polybar Custom" "Твой личный слой кастомизации bar без правки core" \
    "Polybar Preset" "Быстрый выбор профиля: focus/balanced/monitoring" \
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
  "Polybar Custom") open_target panel-custom ;;
  "Polybar Preset") open_target panel-preset ;;
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
    bar) exec "$HOME/.local/bin/app-settings" panel-custom ;;
    appearance) exec lxappearance ;;
    avatar) exec "$HOME/.local/bin/set-user-avatar" --pick ;;
    ssh) exec "$HOME/.local/bin/bind-ssh-key" --pick ;;
    private-files) exec "$HOME/.local/bin/arch-access" ;;
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
    "Polybar" "Быстрая настройка bar и пресетов" \
    "Внешний вид" "GTK-тема, иконки, курсор и шрифты" \
    "Аватар" "Фото пользователя для greeter и lock screen" \
    "SSH ключ" "Привязка SSH ключа к учётке и авто-agent" \
    "Приватные файлы" "Открыть защищённые пути через arch-access" \
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
  Polybar) open_target bar ;;
  "Внешний вид") open_target appearance ;;
  Аватар) open_target avatar ;;
  "SSH ключ") open_target ssh ;;
  "Приватные файлы") open_target private-files ;;
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

  cat > "${CONFIG_DIR}/polybar/scripts/current-desktop-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

current_desktop="$(bspc query -D -d focused --names 2>/dev/null || true)"

if [[ -z "${current_desktop}" ]]; then
  printf '󰆍 ?\n'
  exit 0
fi

printf '󰆍 %s\n' "${current_desktop}"
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
    "${CONFIG_DIR}/polybar/scripts/current-desktop-status" \
    "${CONFIG_DIR}/polybar/scripts/updates-status"
}

write_polybar_user_config() {
  if [[ -f "${CONFIG_DIR}/polybar/user.ini" ]]; then
    warn "Polybar user.ini уже существует, оставляю как есть."
    return
  fi

  cat > "${CONFIG_DIR}/polybar/user.ini" <<'EOF'
; Personal Polybar overrides.
; Измени любые параметры ниже, чтобы настроить бар под себя.
; После правок можно применить так: super+shift+b

[ui]
width = 96%
offset-x = 2%
offset-y = 12
height = 42
radius = 18
padding-left = 2
padding-right = 2
module-margin = 1
modules-left = launcher bspwm
modules-center = xwindow
modules-right = current-desktop updates pulseaudio network bluetooth date tray control power

[colors]
primary = #79D0B8
secondary = #F6C177
alert = #F28FAD
surface = #F1161B21
surface-alt = #F11D252D

[module/xwindow]
label = %title:0:68:...%

[module/date]
date = %d %b
time = %H:%M

; Пример минималистичного профиля:
; [ui]
; modules-right = current-desktop pulseaudio network battery date tray power

; Быстрый выбор профиля без ручной правки:
; ~/.local/bin/polybar-preset
EOF
}

write_polybar_preset_script() {
  cat > "${LOCAL_BIN}/polybar-preset" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

user_file="${HOME}/.config/polybar/user.ini"
mark_begin="# >>> IMBA BAR PRESET >>>"
mark_end="# <<< IMBA BAR PRESET <<<"
preset="${1:-}"

has_battery() {
  local d
  for d in /sys/class/power_supply/*; do
    [[ -f "${d}/type" ]] || continue
    if grep -qx "Battery" "${d}/type"; then
      return 0
    fi
  done
  return 1
}

if [[ -z "${preset}" ]]; then
  preset="$(
    printf '%s\n' "balanced" "focus" "monitoring" |
      rofi -dmenu -i -p "bar preset" -theme "$HOME/.config/rofi/menu.rasi" || true
  )"
fi

battery_module=""
if has_battery; then
  battery_module=" battery"
fi

case "${preset}" in
  balanced)
    modules_right="current-desktop updates pulseaudio network bluetooth${battery_module} date tray control power"
    title_len="64"
    ;;
  focus)
    modules_right="current-desktop pulseaudio network${battery_module} date tray power"
    title_len="86"
    ;;
  monitoring)
    modules_right="current-desktop updates cpu memory pulseaudio network bluetooth${battery_module} date tray control power"
    title_len="54"
    ;;
  *)
    exit 0
    ;;
esac

mkdir -p "${HOME}/.config/polybar"
touch "${user_file}"

tmp_file="$(mktemp)"
trap 'rm -f "${tmp_file}"' EXIT

awk -v begin="${mark_begin}" -v end="${mark_end}" '
  $0 == begin { skip=1; next }
  $0 == end { skip=0; next }
  !skip { print }
' "${user_file}" > "${tmp_file}"

{
  cat "${tmp_file}"
  [[ -s "${tmp_file}" ]] && printf '\n'
  printf '%s\n' "${mark_begin}"
  printf '%s\n' "[ui]"
  printf 'modules-right = %s\n' "${modules_right}"
  printf '%s\n' "[module/xwindow]"
  printf 'label = %%title:0:%s:...%%\n' "${title_len}"
  printf '%s\n' "${mark_end}"
} > "${user_file}"

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  notify-send "Bar preset" "Применён профиль: ${preset}"
fi

bspc wm -r >/dev/null 2>&1 || true
EOF

  chmod +x "${LOCAL_BIN}/polybar-preset"
}

write_bspwm_config() {
  cat > "${CONFIG_DIR}/bspwm/bspwmrc" <<'EOF'
#!/usr/bin/env bash

pgrep -x sxhkd >/dev/null || sxhkd &
pgrep -x picom >/dev/null || picom --config "$HOME/.config/picom/picom.conf" &
pgrep -x dunst >/dev/null || dunst &
pgrep -x light-locker >/dev/null || light-locker --lock-on-suspend --no-late-locking &

"$HOME/.local/bin/launch-polybar"

xsetroot -cursor_name left_ptr
xset s 300 300
xset dpms 600 660 720

if [ -f "$HOME/Pictures/Wallpapers/wallpaper.jpg" ]; then
  feh --bg-fill "$HOME/Pictures/Wallpapers/wallpaper.jpg"
fi

bspc monitor -d 1 2 3 4 5 6 7 8 9 10

bspc config border_width 0
bspc config window_gap 0
bspc config split_ratio 0.52
bspc config borderless_monocle true
bspc config gapless_monocle true
bspc config focus_follows_pointer true
bspc config pointer_modifier mod1
bspc config focused_border_color "#79D0B8"
bspc config active_border_color "#F6C177"
bspc config normal_border_color "#2B343F"
bspc config presel_feedback_color "#F28FAD"

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
# terminal
super + Return
    ~/.local/bin/dropdown-terminal

alt + Return
    ~/.local/bin/dropdown-terminal

# extra terminal
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

# restart polybar
super + ctrl + b
    ~/.local/bin/launch-polybar

alt + ctrl + b
    ~/.local/bin/launch-polybar

# privileged file access
super + ctrl + a
    ~/.local/bin/arch-access

alt + ctrl + a
    ~/.local/bin/arch-access

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
[settings]
screenchange-reload = true
pseudo-transparency = true

[colors]
background = #D60B0F14
surface = #EF151B23
surface-alt = #F0262F3A
foreground = #F6F7F9
muted = #91A0AE
primary = #84D8C2
secondary = #F3C782
accent = #8FB9FF
alert = #F49BB4
border = #28323D
shadow = #00000000

[ui]
width = 96%
offset-x = 2%
offset-y = 12
height = 42
radius = 18
padding-left = 2
padding-right = 2
module-margin = 1
font-main = JetBrainsMono Nerd Font:size=10;2
font-emoji = Noto Color Emoji:size=10;1
modules-left = launcher bspwm
modules-center = xwindow
modules-right = ${POLYBAR_RIGHT_MODULES}

[bar/main]
width = \${ui.width}
offset-x = \${ui.offset-x}
offset-y = \${ui.offset-y}
height = \${ui.height}
radius = \${ui.radius}
background = \${colors.background}
foreground = \${colors.foreground}
border-size = 1
border-color = \${colors.border}
padding-left = \${ui.padding-left}
padding-right = \${ui.padding-right}
module-margin = \${ui.module-margin}
separator =
wm-restack = bspwm
enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize
font-0 = \${ui.font-main}
font-1 = \${ui.font-emoji}
modules-left = \${ui.modules-left}
modules-center = \${ui.modules-center}
modules-right = \${ui.modules-right}
scroll-up = bspc desktop -f prev.local
scroll-down = bspc desktop -f next.local

[module/base]
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 2

[module/launcher]
type = custom/text
content = 󰣇
content-background = \${colors.surface}
content-foreground = \${colors.accent}
content-padding = 2
click-left = ~/.local/bin/open-app-launcher
click-right = ~/.local/bin/bar-context-menu

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
enable-click = true
enable-scroll = false
ws-icon-0 = 1;1
ws-icon-1 = 2;2
ws-icon-2 = 3;3
ws-icon-3 = 4;4
ws-icon-4 = 5;5
ws-icon-5 = 6;6
ws-icon-6 = 7;7
ws-icon-7 = 8;8
ws-icon-8 = 9;9
ws-icon-9 = 10;10
format = <label-state>
format-background = \${colors.surface-alt}
format-foreground = \${colors.foreground}
format-padding = 2
label-focused = %name%
label-focused-background = \${colors.primary}
label-focused-foreground = #0d1116
label-focused-padding = 1
label-focused-margin = 1
label-occupied = %name%
label-occupied-background = transparent
label-occupied-foreground = \${colors.foreground}
label-occupied-padding = 1
label-occupied-margin = 1
label-empty =
label-empty-background = transparent
label-empty-foreground = \${colors.muted}
label-empty-padding = 0
label-empty-margin = 0
label-urgent = %name%
label-urgent-background = \${colors.alert}
label-urgent-foreground = #0d1116
label-urgent-padding = 1
label-urgent-margin = 1

[module/current-desktop]
type = custom/script
exec = ~/.config/polybar/scripts/current-desktop-status
interval = 1
format-background = \${colors.surface-alt}
format-foreground = \${colors.secondary}
format-padding = 2
click-right = ~/.local/bin/bar-context-menu

[module/xwindow]
type = internal/xwindow
format-background = \${colors.surface-alt}
format-foreground = \${colors.foreground}
format-padding = 2
label = %title:0:54:...%
label-empty = workspace
label-empty-foreground = \${colors.muted}
click-right = ~/.local/bin/bar-context-menu

[module/updates]
type = custom/script
exec = ~/.config/polybar/scripts/updates-status
interval = 600
format-background = \${colors.surface}
format-foreground = \${colors.accent}
format-padding = 2
click-left = ~/.local/bin/update-system
click-right = ~/.local/bin/bar-context-menu

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
click-right = ~/.local/bin/bar-context-menu

[module/control]
type = custom/text
content = 󰒓
content-background = \${colors.surface}
content-foreground = \${colors.secondary}
content-padding = 2
click-left = ~/.local/bin/control-center
click-right = ~/.local/bin/bar-context-menu

[module/power]
type = custom/text
content = 󰐥
content-background = \${colors.surface}
content-foreground = \${colors.alert}
content-padding = 2
click-left = ~/.local/bin/power-menu
click-right = ~/.local/bin/lock-screen

[module/tray]
type = internal/tray
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
tray-spacing = 8
tray-size = 65%

include-file = ~/.config/polybar/user.ini
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
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
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
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
[[ -f "${HOME}/.bashrc" ]] && . "${HOME}/.bashrc"
EOF
}

configure_display_manager() {
  info "Настройка LightDM, greeter и lock screen"

  sudo groupadd -f autologin
  sudo gpasswd -a "${USER_NAME}" autologin >/dev/null

  sudo install -d /etc/lightdm/lightdm.conf.d
  cat <<EOF | sudo tee /etc/lightdm/lightdm.conf.d/50-imba-bspwm.conf >/dev/null
[Seat:*]
greeter-session=lightdm-slick-greeter
session-wrapper=/etc/lightdm/Xsession
user-session=bspwm
autologin-user=${USER_NAME}
autologin-session=bspwm
greeter-show-manual-login=true
greeter-hide-users=false
logind-check-graphical=true
EOF

  cat <<'EOF' | sudo tee /etc/lightdm/slick-greeter.conf >/dev/null
[Greeter]
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
background-color=#101418
draw-user-backgrounds=false
EOF

  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  cat <<'EOF' | sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noclear %I $TERM
EOF

  sudo systemctl enable lightdm
  sudo systemctl daemon-reload
  done_msg "LightDM и новый lock screen настроены."
}

configure_ssh_agent() {
  info "Настройка SSH-агента и привязки ключа к учётке"

  local runtime_dir

  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u "${USER_NAME}")}"
  export SSH_AUTH_SOCK="${runtime_dir}/ssh-agent.socket"
  chmod 700 "${USER_HOME}/.ssh"
  ln -sf /usr/lib/systemd/user/ssh-agent.socket \
    "${CONFIG_DIR}/systemd/user/sockets.target.wants/ssh-agent.socket"

  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user enable --now ssh-agent.socket >/dev/null 2>&1 || true

  if [[ -f "${USER_HOME}/.ssh/id_ed25519" ]]; then
    "${LOCAL_BIN}/bind-ssh-key" "${USER_HOME}/.ssh/id_ed25519"
    done_msg "SSH ключ id_ed25519 привязан к учётке."
  elif [[ -f "${USER_HOME}/.ssh/id_rsa" ]]; then
    "${LOCAL_BIN}/bind-ssh-key" "${USER_HOME}/.ssh/id_rsa"
    done_msg "SSH ключ id_rsa привязан к учётке."
  elif [[ -f "${USER_HOME}/.ssh/id_ecdsa" ]]; then
    "${LOCAL_BIN}/bind-ssh-key" "${USER_HOME}/.ssh/id_ecdsa"
    done_msg "SSH ключ id_ecdsa привязан к учётке."
  else
    "${LOCAL_BIN}/bind-ssh-key" --auto
    warn "SSH ключ автоматически не найден. Потом можно выбрать свой через ~/.local/bin/bind-ssh-key --pick."
  fi
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
    "${CONFIG_DIR}/systemd" \
    "${CONFIG_DIR}/sxhkd" \
    "${LOCAL_BIN}" \
    "${USER_HOME}/.ssh" \
    "${WALL_DIR}" \
    "${USER_HOME}/.bash_profile" \
    "${USER_HOME}/.bashrc" \
    "${USER_HOME}/.xinitrc" \
    "${USER_HOME}/.xprofile"
}

start_polybar_now() {
  info "Автозапуск bar по умолчанию"

  if [[ -z "${DISPLAY:-}" ]]; then
    warn "DISPLAY не найден. Bar запустится автоматически при входе в сессию bspwm."
    return
  fi

  if "${LOCAL_BIN}/launch-polybar"; then
    done_msg "Bar запущен."
  else
    warn "Не удалось запустить bar сразу. Проверь ~/.cache/polybar/main.log."
  fi
}

print_next_steps() {
  echo
  printf "%sГотово.%s Рабочий стол теперь будет выглядеть заметно богаче.\n" "${ANSI_DONE}" "${ANSI_RESET}"
  echo
  echo "Что осталось:"
  echo "1. Положи обои сюда:"
  echo "   ${WALLPAPER}"
  echo
  echo "2. Если хочешь свою аватарку на блокировке:"
  echo "   ~/.local/bin/set-user-avatar --pick"
  echo
  echo "3. Если хочешь привязать свой SSH ключ вручную:"
  echo "   ~/.local/bin/bind-ssh-key --pick"
  echo
  echo "4. Доступ к приватным файлам:"
  echo "   ~/.local/bin/arch-access"
  echo
  echo "5. Кастомизация bar без ломки core:"
  echo "   ~/.config/polybar/user.ini"
  echo "   ~/.local/bin/polybar-preset"
  echo
  echo "6. Перезагрузи систему:"
  echo "   sudo reboot"
  echo
  echo "7. Главные хоткеи:"
  echo "   Alt+Return         -> терминал в тайлинге"
  echo "   Alt+Shift+Return   -> ещё один терминал"
  echo "   Alt+d              -> App Deck / выбор приложений"
  echo "   Alt+c              -> quick hub"
  echo "   Alt+s              -> системные настройки"
  echo "   Alt+,              -> настройки приложений"
  echo "   Alt+Shift+p        -> меню питания"
  echo "   Alt+b              -> Firefox"
  echo "   Alt+e              -> Thunar"
  echo "   Alt+q              -> закрыть окно"
  echo "   Alt+Ctrl+b         -> перезапуск bar"
  echo "   Alt+Ctrl+a         -> arch-access (приватные файлы)"
  echo "   Alt+Shift+l        -> lock screen с логином/паролем"
  echo "   Alt+Shift+u        -> обновление системы"
  echo
  echo "Верхняя панель по умолчанию сбалансирована для работы: звук, сеть, Bluetooth, дата, трей и быстрые действия."
  echo "Через ~/.local/bin/polybar-preset можно моментально включить monitoring-профиль с CPU/RAM."
  echo "Правый клик по ключевым модулям bar открывает новое контекстное меню."
  echo "Сессия теперь поднимается через LightDM: есть greeter, поля логина/пароля и аватар пользователя."
  echo "Столы в баре ужаты до цифр, а активный рабочий стол вынесен отдельным индикатором справа."
  echo "Если bar не поднялся, смотри лог: ~/.cache/polybar/main.log"
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
  write_launch_polybar_script
  write_update_script
  write_launcher_script
  write_arch_access_script
  write_bar_context_menu_script
  write_control_center_script
  write_power_menu_script
  write_polybar_preset_script
  write_avatar_script
  write_ssh_key_script
  write_app_settings_script
  write_system_settings_script
  write_polybar_scripts
  write_polybar_user_config
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

  configure_display_manager
  configure_ssh_agent

  info "Проверка аватара пользователя"
  if [[ -f "${USER_HOME}/Pictures/avatar.png" ]]; then
    "${LOCAL_BIN}/set-user-avatar" "${USER_HOME}/Pictures/avatar.png"
    done_msg "Аватар из ~/Pictures/avatar.png применён."
  elif [[ -f "${USER_HOME}/.face" ]]; then
    "${LOCAL_BIN}/set-user-avatar" "${USER_HOME}/.face"
    done_msg "Аватар из ~/.face применён."
  else
    warn "Аватар не найден. Позже можно запустить ~/.local/bin/set-user-avatar --pick."
  fi

  info "fastfetch в bashrc"
  if append_fastfetch; then
    done_msg "fastfetch подключён."
  fi

  info "Права владельца"
  fix_permissions
  done_msg "Владельцы файлов выровнены."

  start_polybar_now

  print_next_steps
}

main "$@"
