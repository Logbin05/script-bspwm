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
readonly SHOTS_DIR="${USER_HOME}/Pictures/Screenshots"
readonly WALLPAPER="${WALL_DIR}/wallpaper.jpg"
readonly IMBA_STATE_DIR="${CONFIG_DIR}/imba-bspwm"
readonly SCRIPT_SOURCE_DIR="${IMBA_SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
readonly SCRIPT_SOURCE_FILE="${IMBA_STATE_DIR}/source-dir"
readonly WALLPAPER_SOURCE_FILE="${IMBA_STATE_DIR}/wallpaper-path"

BATTERY_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "${d}/type" ]] && grep -qx 'Battery' "${d}/type" && basename "${d}" && break
done || true)"
AC_NAME="$(for d in /sys/class/power_supply/*; do
  [[ -f "${d}/type" ]] && grep -Eqx 'Mains|USB|USB_C|USB_PD' "${d}/type" && basename "${d}" && break
done || true)"

BATTERY_NAME="${BATTERY_NAME:-BAT0}"
AC_NAME="${AC_NAME:-AC}"

POLYBAR_RIGHT_MODULES="current-desktop layout wifi-icon bluetooth-icon control updates pulseaudio date tray power"
if [[ -d "/sys/class/power_supply/${BATTERY_NAME}" ]]; then
  POLYBAR_RIGHT_MODULES="current-desktop layout wifi-icon bluetooth-icon control updates pulseaudio battery date tray power"
fi

PACKAGES=(
  accountsservice
  alacritty
  arandr
  brightnessctl
  blueman
  bluez
  bluez-utils
  bspwm
  dbus
  dunst
  fastfetch
  feh
  firefox
  git
  i3lock
  imagemagick
  libnotify
  light-locker
  lightdm
  lightdm-slick-greeter
  lxappearance
  maim
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
  playerctl
  polybar
  rofi
  sxhkd
  thunar
  ttf-jetbrains-mono-nerd
  wireplumber
  xdotool
  xf86-input-libinput
  xorg-xinput
  xorg-setxkbmap
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
  "${CONFIG_DIR}/polybar/fallback.ini"
  "${CONFIG_DIR}/polybar/features.ini"
  "${CONFIG_DIR}/polybar/user.active.ini"
  "${CONFIG_DIR}/polybar/user.ini"
  "${CONFIG_DIR}/polybar/scripts/network-status"
  "${CONFIG_DIR}/polybar/scripts/network-icon"
  "${CONFIG_DIR}/polybar/scripts/bluetooth-status"
  "${CONFIG_DIR}/polybar/scripts/bluetooth-icon"
  "${CONFIG_DIR}/polybar/scripts/current-desktop-status"
  "${CONFIG_DIR}/polybar/scripts/layout-status"
  "${CONFIG_DIR}/polybar/scripts/updates-status"
  "${CONFIG_DIR}/rofi/config.rasi"
  "${CONFIG_DIR}/rofi/launcher.rasi"
  "${CONFIG_DIR}/rofi/menu.rasi"
  "${CONFIG_DIR}/sxhkd/sxhkdrc"
  "${SCRIPT_SOURCE_FILE}"
  "${WALLPAPER_SOURCE_FILE}"
  "${LOCAL_BIN}/apply-monitor-layout"
  "${LOCAL_BIN}/apply-wallpaper"
  "${LOCAL_BIN}/app-settings"
  "${LOCAL_BIN}/arch-access"
  "${LOCAL_BIN}/bar-context-menu"
  "${LOCAL_BIN}/bluetooth-menu"
  "${LOCAL_BIN}/configure-input-devices"
  "${LOCAL_BIN}/control-center"
  "${LOCAL_BIN}/dropdown-terminal"
  "${LOCAL_BIN}/launch-polybar"
  "${LOCAL_BIN}/lock-screen"
  "${LOCAL_BIN}/terminal-modals"
  "${LOCAL_BIN}/toggle-layout"
  "${LOCAL_BIN}/wifi-menu"
  "${LOCAL_BIN}/open-file-manager"
  "${LOCAL_BIN}/open-app-launcher"
  "${LOCAL_BIN}/power-menu"
  "${LOCAL_BIN}/extract-any"
  "${LOCAL_BIN}/take-screenshot"
  "${LOCAL_BIN}/imba-theme"
  "${LOCAL_BIN}/polybar-prepare"
  "${LOCAL_BIN}/polybar-refresh"
  "${LOCAL_BIN}/polybar-preset"
  "${LOCAL_BIN}/bind-ssh-key"
  "${LOCAL_BIN}/set-wallpaper"
  "${LOCAL_BIN}/set-user-avatar"
  "${LOCAL_BIN}/system-settings"
  "${LOCAL_BIN}/update-imba-script"
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
    "${IMBA_STATE_DIR}" \
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
    "${WALL_DIR}" \
    "${SHOTS_DIR}"
}

backup_existing_files() {
  local target

  for target in "${BACKUP_TARGETS[@]}"; do
    backup_if_exists "${target}"
  done
}

package_exists_in_repo() {
  local pkg="$1"
  pacman -Si "${pkg}" >/dev/null 2>&1
}

collect_archive_packages() {
  local extras=()
  local pkg

  for pkg in unzip zip unrar file-roller thunar-archive-plugin; do
    if package_exists_in_repo "${pkg}"; then
      extras+=("${pkg}")
    fi
  done

  if package_exists_in_repo 7zip; then
    extras+=("7zip")
  elif package_exists_in_repo p7zip; then
    extras+=("p7zip")
  fi

  printf '%s\n' "${extras[@]}"
}

install_packages() {
  local packages_to_install=("${PACKAGES[@]}")
  local archive_packages=()

  info "Обновление системы и установка пакетов"

  mapfile -t archive_packages < <(collect_archive_packages)
  if (( ${#archive_packages[@]} > 0 )); then
    packages_to_install+=("${archive_packages[@]}")
  else
    warn "Не удалось подобрать архивные пакеты из репозитория. Распаковщик будет работать через доступные утилиты."
  fi

  sudo pacman -Syu --needed --noconfirm "${packages_to_install[@]}"
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

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/imba-lock"
shot_file="${cache_dir}/shot.png"
lock_file="${cache_dir}/lock.png"
avatar_file="${HOME}/.face"

if [[ -f "${HOME}/Pictures/avatar.png" ]]; then
  avatar_file="${HOME}/Pictures/avatar.png"
fi

fallback_lock() {
  if command -v light-locker-command >/dev/null 2>&1; then
    exec light-locker-command -l
  fi

  if command -v dm-tool >/dev/null 2>&1; then
    exec dm-tool switch-to-greeter
  fi

  printf 'Не удалось заблокировать экран: i3lock/light-locker/dm-tool не найдены.\n' >&2
  exit 1
}

capture_screen() {
  if command -v maim >/dev/null 2>&1; then
    maim -u "${shot_file}" && return 0
  fi

  if command -v import >/dev/null 2>&1; then
    import -window root "${shot_file}" && return 0
  fi

  return 1
}

[[ -n "${DISPLAY:-}" ]] || fallback_lock
command -v i3lock >/dev/null 2>&1 || fallback_lock

mkdir -p "${cache_dir}"

if ! capture_screen; then
  if [[ -f "${HOME}/Pictures/Wallpapers/wallpaper.jpg" ]]; then
    cp "${HOME}/Pictures/Wallpapers/wallpaper.jpg" "${shot_file}"
  else
    if command -v convert >/dev/null 2>&1; then
      convert -size 1920x1080 "xc:#101418" "${shot_file}"
    else
      fallback_lock
    fi
  fi
fi

time_text="$(date '+%H:%M')"
date_text="$(date '+%A, %d %B')"
user_text="$(id -un)@$(hostname -s)"

if command -v convert >/dev/null 2>&1; then
  convert "${shot_file}" \
    -resize 50% -blur 0x7 -resize 200% \
    -fill '#10141877' -colorize 35 \
    "${lock_file}"

  if [[ -f "${avatar_file}" ]]; then
    avatar_tmp="${cache_dir}/avatar-circle.png"
    convert "${avatar_file}" \
      -resize 170x170^ \
      -gravity center -extent 170x170 \
      \( -size 170x170 xc:none -fill white -draw 'circle 85,85 85,6' \) \
      -compose copyopacity -composite \
      "${avatar_tmp}" || true

    if [[ -f "${avatar_tmp}" ]]; then
      convert "${lock_file}" "${avatar_tmp}" \
        -gravity center -geometry +0-110 -composite \
        "${lock_file}"
    fi
  fi

  convert "${lock_file}" \
    -font 'JetBrainsMono Nerd Font' -pointsize 64 -fill '#F5F7FA' -gravity center -annotate +0+42 "${time_text}" \
    -font 'JetBrainsMono Nerd Font' -pointsize 20 -fill '#93A0AD' -gravity center -annotate +0+98 "${date_text}" \
    -font 'JetBrainsMono Nerd Font' -pointsize 16 -fill '#84D8C2' -gravity center -annotate +0+132 "${user_text}" \
    "${lock_file}" || cp "${shot_file}" "${lock_file}"
else
  cp "${shot_file}" "${lock_file}"
fi

if i3lock \
  --nofork \
  --ignore-empty-password \
  --show-failed-attempts \
  --indicator \
  --radius=108 \
  --ring-width=12 \
  --inside-color=101418b5 \
  --ring-color=84d8c288 \
  --line-color=00000000 \
  --keyhl-color=8fb9ffff \
  --bshl-color=f49bb4ff \
  --separator-color=00000000 \
  --insidever-color=84d8c2aa \
  --ringver-color=84d8c2ff \
  --insidewrong-color=f49bb4aa \
  --ringwrong-color=f49bb4ff \
  --verif-color=f5f7faff \
  --wrong-color=f5f7faff \
  --layout-color=8fb9ffff \
  --date-color=93a0adff \
  --time-color=f5f7faff \
  --verif-text='Проверка...' \
  --wrong-text='Неверный пароль' \
  --noinput-text='' \
  --clock \
  --time-str='%H:%M' \
  --date-str='%a %d %b' \
  --image="${lock_file}" \
  --pass-media-keys \
  --pass-screen-keys \
  --pass-volume-keys; then
  exit 0
fi

if i3lock --nofork --image="${lock_file}"; then
  exit 0
fi

fallback_lock
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
fallback_file="${HOME}/.config/polybar/fallback.ini"

mkdir -p "${log_dir}"

notify_msg() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    notify-send "${title}" "${body}"
  fi
}

list_monitors() {
  if command -v polybar >/dev/null 2>&1; then
    polybar --list-monitors 2>/dev/null | cut -d: -f1 || true
    return
  fi
  return 0
}

start_bar_group() {
  local cfg="$1"
  local tag="$2"
  local monitors=""
  local monitor=""
  local pid=""
  local started=0

  if [[ ! -f "${cfg}" ]]; then
    printf '[%s] %s config not found: %s\n' "$(date +'%F %T')" "${tag}" "${cfg}" >> "${log_file}"
    return 1
  fi

  printf '[%s] trying %s config: %s\n' "$(date +'%F %T')" "${tag}" "${cfg}" >> "${log_file}"

  monitors="$(list_monitors)"
  if [[ -z "${monitors}" ]]; then
    monitors="_single_"
  fi

  while IFS= read -r monitor; do
    [[ -n "${monitor}" ]] || continue

    if [[ "${monitor}" == "_single_" ]]; then
      polybar -q main -c "${cfg}" >> "${log_file}" 2>&1 &
    else
      MONITOR="${monitor}" polybar -q main -c "${cfg}" >> "${log_file}" 2>&1 &
    fi

    pid=$!
    sleep 0.4

    if kill -0 "${pid}" >/dev/null 2>&1; then
      started=$((started + 1))
      printf '[%s] polybar started (%s), pid=%s, monitor=%s\n' \
        "$(date +'%F %T')" "${tag}" "${pid}" "${monitor}" >> "${log_file}"
    else
      printf '[%s] polybar failed (%s), monitor=%s\n' \
        "$(date +'%F %T')" "${tag}" "${monitor}" >> "${log_file}"
    fi
  done <<< "${monitors}"

  if (( started > 0 )); then
    return 0
  fi

  printf '[%s] no polybar instances started (%s)\n' "$(date +'%F %T')" "${tag}" >> "${log_file}"
  return 1
}

if ! command -v polybar >/dev/null 2>&1; then
  printf '[%s] polybar command not found\n' "$(date +'%F %T')" >> "${log_file}"
  notify_msg "Polybar missing" "Команда polybar не найдена."
  exit 1
fi

if [[ -z "${DISPLAY:-}" ]]; then
  printf '[%s] DISPLAY is empty, skip launch\n' "$(date +'%F %T')" >> "${log_file}"
  exit 0
fi

printf '\n[%s] launch request\n' "$(date +'%F %T')" >> "${log_file}"
pkill -x polybar >/dev/null 2>&1 || true

if start_bar_group "${config_file}" "main"; then
  exit 0
fi

if start_bar_group "${fallback_file}" "fallback"; then
  notify_msg "Polybar fallback" "Основной конфиг не стартовал, запущен fallback."
  exit 0
fi

notify_msg "Polybar failed" "Не удалось запустить bar. Лог: ~/.cache/polybar/main.log"
exit 1
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

write_self_update_script() {
  cat > "${LOCAL_BIN}/update-imba-script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_CONFIG_HOME:-$HOME/.config}/imba-bspwm/source-dir"

usage() {
  cat <<'USAGE'
Использование: update-imba-script [путь_к_репозиторию] [--apply|--no-apply]
             update-imba-script --set-source <путь_к_репозиторию>

- Без аргументов обновляет репозиторий, который был сохранён установщиком.
- Можно передать путь до repo вручную.
- По умолчанию после обновления автоматически запускает ./script.sh.
- --no-apply: только подтянуть изменения, без применения.
- Команда работает только в git-репозитории.
USAGE
}

notify_msg() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    notify-send "${title}" "${body}"
  fi
}

fail() {
  local msg="$1"
  printf '[ERROR] %s\n' "${msg}" >&2
  notify_msg "Script update failed" "${msg}"
  exit 1
}

store_repo() {
  local repo="$1"
  mkdir -p "$(dirname "${state_file}")"
  printf '%s\n' "${repo}" > "${state_file}"
}

resolve_repo() {
  local arg="${1:-}"

  if [[ -n "${arg}" ]]; then
    printf '%s' "${arg}"
    return
  fi

  if [[ -n "${IMBA_SCRIPT_SOURCE:-}" ]]; then
    printf '%s' "${IMBA_SCRIPT_SOURCE}"
    return
  fi

  if [[ -f "${state_file}" ]]; then
    head -n 1 "${state_file}"
    return
  fi

  printf '%s' "$PWD"
}

apply_mode="apply"
repo_arg=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --set-source)
      [[ $# -ge 2 ]] || fail "Для --set-source нужен путь к репозиторию."
      repo_set="${2/#\~/$HOME}"
      repo_set="$(realpath -m "${repo_set}")"
      [[ -d "${repo_set}/.git" ]] || fail "Путь не похож на git-репозиторий: ${repo_set}"
      store_repo "${repo_set}"
      printf '[OK] Источник обновления сохранён: %s\n' "${repo_set}"
      notify_msg "Script updater" "Новый источник: ${repo_set}"
      exit 0
      ;;
    --no-apply)
      apply_mode="skip"
      shift
      ;;
    --apply)
      apply_mode="apply"
      shift
      ;;
    -*)
      fail "Неизвестный флаг: $1"
      ;;
    *)
      if [[ -n "${repo_arg}" ]]; then
        fail "Передан лишний аргумент: $1"
      fi
      repo_arg="$1"
      shift
      ;;
  esac
done

repo_dir="$(resolve_repo "${repo_arg}")"
repo_dir="${repo_dir/#\~/$HOME}"
repo_dir="$(realpath -m "${repo_dir}")"

command -v git >/dev/null 2>&1 || fail "git не найден."
[[ -d "${repo_dir}" ]] || fail "Каталог не найден: ${repo_dir}"
[[ -d "${repo_dir}/.git" ]] || fail "Это не git-репозиторий: ${repo_dir}"
git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail "Невалидный git-репозиторий: ${repo_dir}"

branch="$(git -C "${repo_dir}" rev-parse --abbrev-ref HEAD)"
[[ "${branch}" != "HEAD" ]] || fail "Детачнутый HEAD. Переключись на обычную ветку перед обновлением."

repo_dirty=0
repo_untracked=0
manual_stash_ref=""
if ! git -C "${repo_dir}" diff --quiet || ! git -C "${repo_dir}" diff --cached --quiet; then
  repo_dirty=1
fi
if [[ -n "$(git -C "${repo_dir}" ls-files --others --exclude-standard)" ]]; then
  repo_dirty=1
  repo_untracked=1
fi

store_repo "${repo_dir}"
printf '[INFO] Проверяю обновления setup-скрипта в %s\n' "${repo_dir}"

upstream_ref="$(git -C "${repo_dir}" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -n "${upstream_ref}" ]]; then
  remote_name="${upstream_ref%%/*}"
  remote_branch="${upstream_ref#*/}"
else
  remote_name="origin"
  remote_branch="${branch}"
fi

git -C "${repo_dir}" fetch --quiet "${remote_name}" "${remote_branch}" || fail "Не удалось получить изменения с ${remote_name}/${remote_branch}."

local_sha="$(git -C "${repo_dir}" rev-parse HEAD)"
remote_sha="$(git -C "${repo_dir}" rev-parse "${remote_name}/${remote_branch}" 2>/dev/null || true)"

if [[ -z "${remote_sha}" ]]; then
  fail "Не удалось определить ${remote_name}/${remote_branch}."
fi

if [[ "${local_sha}" == "${remote_sha}" ]]; then
  printf '[OK] Скрипт уже актуален.\n'
  notify_msg "Script updater" "Новых обновлений нет."
  exit 0
fi

behind_count="$(git -C "${repo_dir}" rev-list --count "${local_sha}..${remote_sha}" 2>/dev/null || echo '?')"
printf '[INFO] Найдено %s новых коммит(ов), обновляю...\n' "${behind_count}"

if (( repo_dirty == 1 )); then
  printf '[INFO] Обнаружены локальные изменения. Пробую update с auto-stash...\n'
fi

if (( repo_untracked == 1 )); then
  stash_msg="imba-updater-untracked-$(date +%s)"
  git -C "${repo_dir}" stash push --include-untracked -m "${stash_msg}" >/dev/null 2>&1 || true
  manual_stash_ref="$(
    git -C "${repo_dir}" stash list |
      awk -v msg="${stash_msg}" '$0 ~ msg {print $1; exit}' || true
  )"
fi

if ! git -C "${repo_dir}" pull --rebase --autostash "${remote_name}" "${remote_branch}"; then
  if [[ -n "${manual_stash_ref}" ]]; then
    fail "Не удалось применить обновление. Локальные untracked сохранены в ${manual_stash_ref}. Верни их: git -C ${repo_dir} stash pop ${manual_stash_ref}"
  fi
  fail "Не удалось применить обновление (rebase/autostash). Проверь git status в ${repo_dir}."
fi

if [[ -n "${manual_stash_ref}" ]]; then
  if ! git -C "${repo_dir}" stash pop --index "${manual_stash_ref}" >/dev/null 2>&1; then
    fail "Обновление прошло, но не удалось вернуть изменения из ${manual_stash_ref}. Верни вручную: git -C ${repo_dir} stash pop ${manual_stash_ref}"
  fi
fi

new_short_sha="$(git -C "${repo_dir}" rev-parse --short HEAD)"
printf '[OK] Скрипт обновлён до %s\n' "${new_short_sha}"
notify_msg "Script updater" "Обновлено до ${new_short_sha}"

if [[ "${apply_mode}" == "skip" ]]; then
  printf '[INFO] Автоприменение отключено (--no-apply).\n'
  exit 0
fi

setup_script="${repo_dir}/script.sh"
[[ -f "${setup_script}" ]] || fail "После обновления не найден script.sh в ${repo_dir}"
chmod +x "${setup_script}" >/dev/null 2>&1 || true

printf '[INFO] Применяю обновление: запускаю %s\n' "${setup_script}"
notify_msg "Script updater" "Обновление получено, запускаю применение..."

if [[ -t 1 ]]; then
  (cd "${repo_dir}" && ./script.sh) || fail "Автоприменение завершилось с ошибкой."
  printf '[OK] Обновление применено.\n'
  notify_msg "Script updater" "Обновление успешно применено."
  exit 0
fi

if [[ -n "${DISPLAY:-}" ]] && command -v alacritty >/dev/null 2>&1; then
  printf '[INFO] Открою отдельное окно терминала для применения обновления.\n'
  repo_q=""
  printf -v repo_q '%q' "${repo_dir}"
  alacritty --class settings-editor -e bash -lc "cd ${repo_q}; ./script.sh; status=\$?; echo; if [[ \$status -eq 0 ]]; then echo '[OK] Обновление применено.'; else echo '[ERROR] Автоприменение завершилось с ошибкой.'; fi; read -n 1 -s -r -p 'Нажми любую клавишу для закрытия...'; exit \$status" >/dev/null 2>&1 &
  exit 0
fi

(cd "${repo_dir}" && ./script.sh) || fail "Автоприменение завершилось с ошибкой."
printf '[OK] Обновление применено.\n'
notify_msg "Script updater" "Обновление успешно применено."
EOF

  chmod +x "${LOCAL_BIN}/update-imba-script"
}

write_script_source_marker() {
  printf '%s\n' "${SCRIPT_SOURCE_DIR}" > "${SCRIPT_SOURCE_FILE}"
}

write_wallpaper_scripts() {
  cat > "${LOCAL_BIN}/apply-wallpaper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_file="${XDG_CONFIG_HOME:-$HOME/.config}/imba-bspwm/wallpaper-path"
default_wall="${HOME}/Pictures/Wallpapers/wallpaper.jpg"
source_path=""

if [[ -f "${state_file}" ]]; then
  source_path="$(head -n 1 "${state_file}")"
fi

if [[ -z "${source_path}" || ! -f "${source_path}" ]]; then
  source_path="${default_wall}"
fi

if [[ ! -f "${source_path}" ]]; then
  printf '[WARN] Wallpaper not found: %s\n' "${source_path}" >&2
  exit 1
fi

if command -v feh >/dev/null 2>&1; then
  feh --bg-fill "${source_path}"
fi
EOF

  chmod +x "${LOCAL_BIN}/apply-wallpaper"

  cat > "${LOCAL_BIN}/set-wallpaper" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/imba-bspwm"
state_file="${state_dir}/wallpaper-path"
target_dir="${HOME}/Pictures/Wallpapers"
target_file="${target_dir}/wallpaper.jpg"
source_path="${1:-}"

pick_wallpaper() {
  if command -v yad >/dev/null 2>&1; then
    yad \
      --file \
      --title="Выбери обои" \
      --file-filter="Images | *.png *.jpg *.jpeg *.webp *.bmp" || true
    return
  fi

  printf 'Введи путь до обоев: ' >&2
  read -r source_path || true
  printf '%s' "${source_path}"
}

if [[ -z "${source_path}" || "${source_path}" == "--pick" ]]; then
  source_path="$(pick_wallpaper)"
fi

[[ -n "${source_path}" ]] || exit 0

source_path="${source_path/#\~/$HOME}"
source_path="$(realpath -m "${source_path}")"
[[ -f "${source_path}" ]] || {
  printf '[ERROR] Файл не найден: %s\n' "${source_path}" >&2
  exit 1
}

mkdir -p "${target_dir}" "${state_dir}"
cp -f "${source_path}" "${target_file}"
printf '%s\n' "${target_file}" > "${state_file}"

"${HOME}/.local/bin/apply-wallpaper" || true

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  notify-send "Обои применены" "${source_path##*/}"
fi
EOF

  chmod +x "${LOCAL_BIN}/set-wallpaper"
}

write_extract_script() {
  cat > "${LOCAL_BIN}/extract-any" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

archive="${1:---pick}"
target_dir="${2:-}"

usage() {
  cat <<'USAGE'
Использование: extract-any [архив|--pick] [папка_назначения]

Примеры:
  extract-any --pick
  extract-any ~/Downloads/file.zip
  extract-any ~/Downloads/file.rar ~/Downloads/unpacked
USAGE
}

notify_msg() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    notify-send "${title}" "${body}"
  fi
}

pick_archive() {
  local selected=""

  if command -v yad >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      yad \
        --file \
        --title="Выбери архив для распаковки" \
        --file-filter="Archives | *.zip *.rar *.7z *.tar *.tar.gz *.tgz *.tar.bz2 *.tbz2 *.tar.xz *.txz *.tar.zst *.tzst *.gz *.bz2 *.xz *.zst *.iso" || true
    )"
  elif command -v rofi >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      find "$HOME" -maxdepth 4 -type f \
        \( -iname "*.zip" -o -iname "*.rar" -o -iname "*.7z" -o -iname "*.tar" -o -iname "*.tar.gz" -o -iname "*.tgz" -o -iname "*.tar.bz2" -o -iname "*.tbz2" -o -iname "*.tar.xz" -o -iname "*.txz" -o -iname "*.tar.zst" -o -iname "*.tzst" -o -iname "*.gz" -o -iname "*.bz2" -o -iname "*.xz" -o -iname "*.zst" -o -iname "*.iso" \) 2>/dev/null |
        rofi -dmenu -i -p "archive path" -theme "$HOME/.config/rofi/menu.rasi" || true
    )"
  else
    printf 'Введи путь к архиву: ' >&2
    read -r selected || true
  fi

  printf '%s' "${selected}"
}

default_target_dir() {
  local path="$1"
  local name

  name="$(basename "${path}")"
  name="${name%.tar.gz}"
  name="${name%.tar.bz2}"
  name="${name%.tar.xz}"
  name="${name%.tar.zst}"
  name="${name%.tgz}"
  name="${name%.tbz2}"
  name="${name%.txz}"
  name="${name%.tzst}"
  name="${name%.zip}"
  name="${name%.rar}"
  name="${name%.7z}"
  name="${name%.tar}"
  name="${name%.gz}"
  name="${name%.bz2}"
  name="${name%.xz}"
  name="${name%.zst}"
  name="${name%.iso}"

  if [[ -z "${name}" ]]; then
    name="unpacked"
  fi

  printf '%s' "${PWD}/${name}"
}

extract_with_7z() {
  local src="$1"
  local dst="$2"

  command -v 7z >/dev/null 2>&1 || return 1
  7z x -y -aoa "-o${dst}" -- "${src}"
}

extract_with_bsdtar() {
  local src="$1"
  local dst="$2"

  command -v bsdtar >/dev/null 2>&1 || return 1
  bsdtar -xf "${src}" -C "${dst}"
}

extract_with_unzip() {
  local src="$1"
  local dst="$2"

  command -v unzip >/dev/null 2>&1 || return 1
  unzip -o "${src}" -d "${dst}"
}

extract_with_unrar() {
  local src="$1"
  local dst="$2"

  command -v unrar >/dev/null 2>&1 || return 1
  unrar x -o+ "${src}" "${dst}/"
}

case "${archive}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [[ "${archive}" == "--pick" || -z "${archive}" ]]; then
  archive="$(pick_archive)"
fi

[[ -n "${archive}" ]] || exit 0

archive="${archive/#\~/$HOME}"
archive="$(realpath -m "${archive}")"
[[ -f "${archive}" ]] || {
  printf '[ERROR] Архив не найден: %s\n' "${archive}" >&2
  exit 1
}

if [[ -z "${target_dir}" ]]; then
  target_dir="$(default_target_dir "${archive}")"
fi

target_dir="${target_dir/#\~/$HOME}"
target_dir="$(realpath -m "${target_dir}")"
mkdir -p "${target_dir}"

lower_archive="$(printf '%s' "${archive}" | tr '[:upper:]' '[:lower:]')"
ok=0

if extract_with_7z "${archive}" "${target_dir}" >/dev/null 2>&1; then
  ok=1
elif [[ "${lower_archive}" == *.zip ]] && extract_with_unzip "${archive}" "${target_dir}" >/dev/null 2>&1; then
  ok=1
elif [[ "${lower_archive}" == *.rar ]] && extract_with_unrar "${archive}" "${target_dir}" >/dev/null 2>&1; then
  ok=1
elif extract_with_bsdtar "${archive}" "${target_dir}" >/dev/null 2>&1; then
  ok=1
fi

if (( ok == 0 )); then
  printf '[ERROR] Не удалось распаковать: %s\n' "${archive}" >&2
  printf '[ERROR] Установи 7zip/unrar/unzip/bsdtar и попробуй снова.\n' >&2
  exit 1
fi

notify_msg "Архив распакован" "${target_dir}"
printf '%s\n' "${target_dir}"
EOF

  chmod +x "${LOCAL_BIN}/extract-any"
}

write_screenshot_script() {
  cat > "${LOCAL_BIN}/take-screenshot" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

shots_dir="${HOME}/Pictures/Screenshots"
mode="${1:---pick}"

notify_msg() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    notify-send "${title}" "${body}"
  fi
}

pick_mode() {
  local selected=""

  if command -v rofi >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      printf '%s\n' \
        "Весь экран" \
        "Выделить область" \
        "Активное окно" |
        rofi -dmenu -i -p "screenshot" -theme "$HOME/.config/rofi/menu.rasi" || true
    )"
  elif command -v yad >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      printf '%s\n' \
        "Весь экран" \
        "Выделить область" \
        "Активное окно" |
        yad --list \
          --title="Скриншот" \
          --width=420 \
          --height=260 \
          --center \
          --column="Режим" \
          --separator="|" \
          --button="Снять:0" \
          --button="Отмена:1" 2>/dev/null || true
    )"
    selected="${selected%%|*}"
  else
    printf 'Режим (full/area/window): ' >&2
    read -r selected || true
  fi

  case "${selected}" in
    "Весь экран"|full|--full) printf '%s' "--full" ;;
    "Выделить область"|area|--area) printf '%s' "--area" ;;
    "Активное окно"|window|--window) printf '%s' "--window" ;;
    *) printf '%s' "" ;;
  esac
}

take_window() {
  local output="$1"
  local win_id=""

  if command -v xdotool >/dev/null 2>&1; then
    win_id="$(xdotool getactivewindow 2>/dev/null || true)"
  fi

  if [[ -n "${win_id}" ]]; then
    maim -u -i "${win_id}" "${output}"
    return
  fi

  maim -u "${output}"
}

if [[ -z "${DISPLAY:-}" ]]; then
  printf '[ERROR] DISPLAY не найден. Скриншот доступен только в графической сессии.\n' >&2
  exit 1
fi

if ! command -v maim >/dev/null 2>&1; then
  printf '[ERROR] maim не найден. Установи пакет maim.\n' >&2
  exit 1
fi

if [[ "${mode}" == "--pick" || "${mode}" == "pick" ]]; then
  mode="$(pick_mode)"
fi

[[ -n "${mode}" ]] || exit 0

mkdir -p "${shots_dir}"
timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
output="${shots_dir}/shot_${timestamp}.png"

case "${mode}" in
  --full|full)
    maim -u "${output}"
    ;;
  --area|area)
    maim -s -u "${output}"
    ;;
  --window|window)
    take_window "${output}"
    ;;
  *)
    printf '[ERROR] Неизвестный режим: %s\n' "${mode}" >&2
    exit 1
    ;;
esac

if [[ ! -s "${output}" ]]; then
  printf '[ERROR] Скриншот не сохранён.\n' >&2
  exit 1
fi

clip_note=""
if command -v xclip >/dev/null 2>&1; then
  xclip -selection clipboard -t image/png -i "${output}" >/dev/null 2>&1 || true
  clip_note=" и скопирован в буфер"
fi

notify_msg "Скриншот готов" "${output##*/}${clip_note}"
printf '%s\n' "${output}"
EOF

  chmod +x "${LOCAL_BIN}/take-screenshot"
}

write_theme_script() {
  cat > "${LOCAL_BIN}/imba-theme" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

theme="${1:-}"
state_dir="${XDG_CONFIG_HOME:-$HOME/.config}/imba-bspwm"
state_file="${state_dir}/theme"

polybar_file="${HOME}/.config/polybar/config.ini"
rofi_launcher="${HOME}/.config/rofi/launcher.rasi"
rofi_menu="${HOME}/.config/rofi/menu.rasi"
dunst_file="${HOME}/.config/dunst/dunstrc"

list_themes() {
  printf '%s\n' "ocean" "sunset" "forest" "nord" "graphite"
}

notify_msg() {
  local title="$1"
  local body="$2"
  if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    notify-send "${title}" "${body}"
  fi
}

pick_theme() {
  local selected=""

  if command -v rofi >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      list_themes | rofi -dmenu -i -p "theme" -theme "$HOME/.config/rofi/menu.rasi" || true
    )"
  elif command -v yad >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    selected="$(
      list_themes |
        yad --list \
          --title="Темы интерфейса" \
          --width=420 \
          --height=300 \
          --center \
          --column="Тема" \
          --separator="|" \
          --button="Применить:0" \
          --button="Отмена:1" 2>/dev/null || true
    )"
    selected="${selected%%|*}"
  else
    printf 'Тема (%s): ' "$(list_themes | tr '\n' '/' | sed 's#/$##')" >&2
    read -r selected || true
  fi

  printf '%s' "${selected}"
}

set_ini_key() {
  local section="$1"
  local key="$2"
  local value="$3"
  local file="$4"
  local tmp_file

  [[ -f "${file}" ]] || return 0
  tmp_file="$(mktemp)"

  awk -v target_section="${section}" -v target_key="${key}" -v target_value="${value}" '
    BEGIN {
      in_target = 0
      section_found = 0
      key_written = 0
    }

    function print_value() {
      printf "%s = %s\n", target_key, target_value
      key_written = 1
    }

    {
      line = $0

      if (match(line, /^[[:space:]]*\[[^]]+\][[:space:]]*$/)) {
        if (in_target && !key_written) {
          print_value()
        }

        section_name = line
        gsub(/^[[:space:]]*\[/, "", section_name)
        gsub(/\][[:space:]]*$/, "", section_name)

        if (tolower(section_name) == tolower(target_section)) {
          in_target = 1
          section_found = 1
        } else {
          in_target = 0
        }

        print line
        next
      }

      if (in_target && match(line, "^[[:space:]]*" target_key "[[:space:]]*=")) {
        if (!key_written) {
          print_value()
        }
        next
      }

      print line
    }

    END {
      if (!section_found) {
        print ""
        printf "[%s]\n", target_section
        print_value()
      } else if (in_target && !key_written) {
        print_value()
      }
    }
  ' "${file}" > "${tmp_file}"

  mv "${tmp_file}" "${file}"
}

set_rasi_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  [[ -f "${file}" ]] || return 0
  sed -E -i "s@^([[:space:]]*${key}[[:space:]]*:[[:space:]]*)[^;]+;@\\1${value};@g" "${file}"
}

apply_palette() {
  case "$1" in
    ocean|default)
      pb_background="#D80C1118"
      pb_surface="#EB131A23"
      pb_surface_alt="#F018212B"
      pb_foreground="#ECF2F8"
      pb_muted="#8EA0B2"
      pb_primary="#84D8C2"
      pb_secondary="#F3C782"
      pb_accent="#8FB9FF"
      pb_alert="#F49BB4"
      pb_border="#22303D"
      rofi_bg="#0f1418ee"
      rofi_bg_panel="#161b21ff"
      rofi_bg_card="#1d252dff"
      rofi_fg="#f5f7faff"
      rofi_muted="#93a0adff"
      rofi_accent="#79d0b8ff"
      rofi_urgent="#f28fadff"
      rofi_border="#2b343fff"
      rofi_menu_bg="#101418ee"
      rofi_menu_accent="#f6c177ff"
      dunst_bg="#101418"
      dunst_fg="#F5F7FA"
      dunst_frame_low="#2B343F"
      dunst_frame_normal="#79D0B8"
      dunst_frame_critical="#F28FAD"
      ;;
    sunset)
      pb_background="#D81A1010"
      pb_surface="#EB231617"
      pb_surface_alt="#F02A1B1E"
      pb_foreground="#F8EEE8"
      pb_muted="#BDA598"
      pb_primary="#F4A261"
      pb_secondary="#E9C46A"
      pb_accent="#E76F51"
      pb_alert="#FF6B6B"
      pb_border="#4B2F32"
      rofi_bg="#1a1010ee"
      rofi_bg_panel="#231617ff"
      rofi_bg_card="#2a1b1eff"
      rofi_fg="#f8eee8ff"
      rofi_muted="#bda598ff"
      rofi_accent="#f4a261ff"
      rofi_urgent="#ff6b6bff"
      rofi_border="#4b2f32ff"
      rofi_menu_bg="#1a1010ee"
      rofi_menu_accent="#e9c46aff"
      dunst_bg="#1A1010"
      dunst_fg="#F8EEE8"
      dunst_frame_low="#4B2F32"
      dunst_frame_normal="#F4A261"
      dunst_frame_critical="#FF6B6B"
      ;;
    forest)
      pb_background="#D70A1611"
      pb_surface="#E914221B"
      pb_surface_alt="#EF1A2B22"
      pb_foreground="#EAF5EE"
      pb_muted="#8FA99A"
      pb_primary="#6FCF97"
      pb_secondary="#B7D879"
      pb_accent="#56CCF2"
      pb_alert="#EB5757"
      pb_border="#1F3A2F"
      rofi_bg="#0a1611ee"
      rofi_bg_panel="#14221bff"
      rofi_bg_card="#1a2b22ff"
      rofi_fg="#eaf5eeff"
      rofi_muted="#8fa99aff"
      rofi_accent="#6fcf97ff"
      rofi_urgent="#eb5757ff"
      rofi_border="#1f3a2fff"
      rofi_menu_bg="#0a1611ee"
      rofi_menu_accent="#b7d879ff"
      dunst_bg="#0A1611"
      dunst_fg="#EAF5EE"
      dunst_frame_low="#1F3A2F"
      dunst_frame_normal="#6FCF97"
      dunst_frame_critical="#EB5757"
      ;;
    nord)
      pb_background="#D82B313D"
      pb_surface="#EB3B4252"
      pb_surface_alt="#F0434C5E"
      pb_foreground="#ECEFF4"
      pb_muted="#AAB3C5"
      pb_primary="#88C0D0"
      pb_secondary="#EBCB8B"
      pb_accent="#81A1C1"
      pb_alert="#BF616A"
      pb_border="#4C566A"
      rofi_bg="#2b313dee"
      rofi_bg_panel="#3b4252ff"
      rofi_bg_card="#434c5eff"
      rofi_fg="#eceff4ff"
      rofi_muted="#aab3c5ff"
      rofi_accent="#88c0d0ff"
      rofi_urgent="#bf616aff"
      rofi_border="#4c566aff"
      rofi_menu_bg="#2b313dee"
      rofi_menu_accent="#ebcb8bff"
      dunst_bg="#2B313D"
      dunst_fg="#ECEFF4"
      dunst_frame_low="#4C566A"
      dunst_frame_normal="#88C0D0"
      dunst_frame_critical="#BF616A"
      ;;
    graphite)
      pb_background="#D8141518"
      pb_surface="#EB1D1F24"
      pb_surface_alt="#F0252830"
      pb_foreground="#ECEDEF"
      pb_muted="#9CA1AB"
      pb_primary="#C6CAD1"
      pb_secondary="#A7B0BE"
      pb_accent="#D0D7E3"
      pb_alert="#F47174"
      pb_border="#30343D"
      rofi_bg="#141518ee"
      rofi_bg_panel="#1d1f24ff"
      rofi_bg_card="#252830ff"
      rofi_fg="#ecedefff"
      rofi_muted="#9ca1abff"
      rofi_accent="#c6cad1ff"
      rofi_urgent="#f47174ff"
      rofi_border="#30343dff"
      rofi_menu_bg="#141518ee"
      rofi_menu_accent="#d0d7e3ff"
      dunst_bg="#141518"
      dunst_fg="#ECEDEF"
      dunst_frame_low="#30343D"
      dunst_frame_normal="#C6CAD1"
      dunst_frame_critical="#F47174"
      ;;
    *)
      return 1
      ;;
  esac

  return 0
}

case "${theme}" in
  -h|--help)
    printf 'Использование: imba-theme [theme]\n'
    printf 'Темы: %s\n' "$(list_themes | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
    exit 0
    ;;
  --list)
    list_themes
    exit 0
    ;;
esac

if [[ -z "${theme}" || "${theme}" == "--pick" ]]; then
  theme="$(pick_theme)"
fi

[[ -n "${theme}" ]] || exit 0

if ! apply_palette "${theme}"; then
  printf '[ERROR] Неизвестная тема: %s\n' "${theme}" >&2
  exit 1
fi

mkdir -p "${state_dir}"
printf '%s\n' "${theme}" > "${state_file}"

set_ini_key "colors" "background" "${pb_background}" "${polybar_file}"
set_ini_key "colors" "surface" "${pb_surface}" "${polybar_file}"
set_ini_key "colors" "surface-alt" "${pb_surface_alt}" "${polybar_file}"
set_ini_key "colors" "foreground" "${pb_foreground}" "${polybar_file}"
set_ini_key "colors" "muted" "${pb_muted}" "${polybar_file}"
set_ini_key "colors" "primary" "${pb_primary}" "${polybar_file}"
set_ini_key "colors" "secondary" "${pb_secondary}" "${polybar_file}"
set_ini_key "colors" "accent" "${pb_accent}" "${polybar_file}"
set_ini_key "colors" "alert" "${pb_alert}" "${polybar_file}"
set_ini_key "colors" "border" "${pb_border}" "${polybar_file}"

set_rasi_var "${rofi_launcher}" "bg" "${rofi_bg}"
set_rasi_var "${rofi_launcher}" "bg-panel" "${rofi_bg_panel}"
set_rasi_var "${rofi_launcher}" "bg-card" "${rofi_bg_card}"
set_rasi_var "${rofi_launcher}" "fg" "${rofi_fg}"
set_rasi_var "${rofi_launcher}" "muted" "${rofi_muted}"
set_rasi_var "${rofi_launcher}" "accent" "${rofi_accent}"
set_rasi_var "${rofi_launcher}" "urgent" "${rofi_urgent}"
set_rasi_var "${rofi_launcher}" "border" "${rofi_border}"

set_rasi_var "${rofi_menu}" "bg" "${rofi_menu_bg}"
set_rasi_var "${rofi_menu}" "bg-panel" "${rofi_bg_panel}"
set_rasi_var "${rofi_menu}" "bg-card" "${rofi_bg_card}"
set_rasi_var "${rofi_menu}" "fg" "${rofi_fg}"
set_rasi_var "${rofi_menu}" "muted" "${rofi_muted}"
set_rasi_var "${rofi_menu}" "accent" "${rofi_menu_accent}"
set_rasi_var "${rofi_menu}" "border" "${rofi_border}"

set_ini_key "global" "background" "\"${dunst_bg}\"" "${dunst_file}"
set_ini_key "global" "foreground" "\"${dunst_fg}\"" "${dunst_file}"
set_ini_key "global" "frame_color" "\"${dunst_frame_normal}\"" "${dunst_file}"
set_ini_key "urgency_low" "background" "\"${dunst_bg}\"" "${dunst_file}"
set_ini_key "urgency_low" "foreground" "\"${dunst_fg}\"" "${dunst_file}"
set_ini_key "urgency_low" "frame_color" "\"${dunst_frame_low}\"" "${dunst_file}"
set_ini_key "urgency_normal" "background" "\"${dunst_bg}\"" "${dunst_file}"
set_ini_key "urgency_normal" "foreground" "\"${dunst_fg}\"" "${dunst_file}"
set_ini_key "urgency_normal" "frame_color" "\"${dunst_frame_normal}\"" "${dunst_file}"
set_ini_key "urgency_critical" "background" "\"${dunst_bg}\"" "${dunst_file}"
set_ini_key "urgency_critical" "foreground" "\"${dunst_fg}\"" "${dunst_file}"
set_ini_key "urgency_critical" "frame_color" "\"${dunst_frame_critical}\"" "${dunst_file}"

"${HOME}/.local/bin/polybar-refresh" >/dev/null 2>&1 || true
pkill -x dunst >/dev/null 2>&1 || true
dunst >/dev/null 2>&1 &

notify_msg "Тема применена" "${theme}"
printf '[OK] Тема применена: %s\n' "${theme}"
EOF

  chmod +x "${LOCAL_BIN}/imba-theme"
}

write_monitor_layout_script() {
  cat > "${LOCAL_BIN}/apply-monitor-layout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

mapfile -t monitors < <(bspc query -M --names 2>/dev/null || true)

if (( ${#monitors[@]} == 0 )); then
  exit 0
fi

primary_slots="${IMBA_PRIMARY_MONITOR_DESKTOPS:-10}"
extra_slots="${IMBA_EXTRA_MONITOR_DESKTOPS:-5}"

if [[ ! "${primary_slots}" =~ ^[1-9][0-9]*$ ]]; then
  primary_slots=10
fi

if [[ ! "${extra_slots}" =~ ^[1-9][0-9]*$ ]]; then
  extra_slots=5
fi

desktop_counter=1

for i in "${!monitors[@]}"; do
  monitor="${monitors[$i]}"
  desktops=()
  slots="${extra_slots}"

  if (( i == 0 )); then
    slots="${primary_slots}"
  fi

  for ((j = 0; j < slots; j++)); do
    desktops+=("${desktop_counter}")
    ((desktop_counter++))
  done

  bspc monitor "${monitor}" -d "${desktops[@]}"
done
EOF

  chmod +x "${LOCAL_BIN}/apply-monitor-layout"
}

write_input_devices_script() {
  cat > "${LOCAL_BIN}/configure-input-devices" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v xinput >/dev/null 2>&1; then
  exit 0
fi

mapfile -t touchpads < <(
  xinput list --name-only 2>/dev/null |
    grep -Ei 'touchpad|trackpad|synaptics|elan|glidepoint' || true
)

for device in "${touchpads[@]}"; do
  xinput set-prop "${device}" "libinput Tapping Enabled" 1 >/dev/null 2>&1 || true
  # 2-finger tap -> right click (context menu), 3-finger -> middle click
  xinput set-prop "${device}" "libinput Tapping Button Mapping Enabled" 1 0 >/dev/null 2>&1 || true
  # Clickfinger mode improves right-click behavior on many touchpads
  xinput set-prop "${device}" "libinput Click Method Enabled" 0 1 >/dev/null 2>&1 || true
  xinput set-prop "${device}" "libinput Natural Scrolling Enabled" 1 >/dev/null 2>&1 || true
  xinput set-prop "${device}" "libinput Disable While Typing Enabled" 1 >/dev/null 2>&1 || true
  xinput set-prop "${device}" "libinput Tapping Drag Enabled" 1 >/dev/null 2>&1 || true
done
EOF

  chmod +x "${LOCAL_BIN}/configure-input-devices"
}

write_layout_scripts() {
  cat > "${LOCAL_BIN}/toggle-layout" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v setxkbmap >/dev/null 2>&1; then
  printf '[ERROR] setxkbmap not found.\n' >&2
  exit 1
fi

primary="${IMBA_LAYOUT_PRIMARY:-us}"
secondary="${IMBA_LAYOUT_SECONDARY:-ru}"

current="$(
  setxkbmap -query 2>/dev/null |
    awk '/layout:/ {print $2; exit}' |
    cut -d',' -f1 |
    tr '[:upper:]' '[:lower:]'
)"

if [[ "${current}" == "${secondary}" ]]; then
  next="${primary}"
else
  next="${secondary}"
fi

setxkbmap -layout "${next}"

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  notify-send "Keyboard layout" "$(printf '%s' "${next}" | tr '[:lower:]' '[:upper:]')"
fi
EOF

  chmod +x "${LOCAL_BIN}/toggle-layout"
}

write_terminal_modals_script() {
  cat > "${LOCAL_BIN}/terminal-modals" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

run_wifi() {
  if command -v nmtui >/dev/null 2>&1; then
    nmtui || true
    return
  fi
  nm-connection-editor >/dev/null 2>&1 || true
}

run_bluetooth() {
  if command -v bluetoothctl >/dev/null 2>&1; then
    bluetoothctl || true
    return
  fi
  blueman-manager >/dev/null 2>&1 || true
}

run_audio() {
  pavucontrol >/dev/null 2>&1 || true
}

run_display() {
  arandr >/dev/null 2>&1 || true
}

run_theme() {
  "$HOME/.local/bin/imba-theme" --pick || true
}

run_wallpaper() {
  "$HOME/.local/bin/set-wallpaper" --pick || true
}

run_archives() {
  "$HOME/.local/bin/extract-any" --pick || true
}

run_screenshot() {
  "$HOME/.local/bin/take-screenshot" --pick || true
}

run_updates() {
  "$HOME/.local/bin/update-imba-script" || true
}

run_power() {
  "$HOME/.local/bin/power-menu" || true
}

open_in_alacritty() {
  local mode="$1"

  if command -v alacritty >/dev/null 2>&1; then
    alacritty --class settings-editor -e "$0" "${mode}" --tty >/dev/null 2>&1 &
    exit 0
  fi
}

show_menu() {
  while true; do
    clear
    cat <<'MENU'
=== BSPWM-UNICRON Terminal Modals ===
1) Wi-Fi (nmtui)
2) Bluetooth (bluetoothctl)
3) Audio
4) Display
5) Theme
6) Wallpaper
7) Archives
8) Screenshot
9) Update setup (auto-apply)
10) Power menu
0) Exit
MENU

    printf 'Выбор: '
    read -r choice || true

    case "${choice}" in
      1) run_wifi ;;
      2) run_bluetooth ;;
      3) run_audio ;;
      4) run_display ;;
      5) run_theme ;;
      6) run_wallpaper ;;
      7) run_archives ;;
      8) run_screenshot ;;
      9) run_updates ;;
      10) run_power ;;
      0|q|Q|exit) exit 0 ;;
      *) printf 'Неизвестный пункт.\n'; sleep 1 ;;
    esac
  done
}

mode="${1:-menu}"
force_tty="${2:-}"

case "${mode}" in
  wifi)
    [[ "${force_tty}" == "--tty" || -t 1 ]] || open_in_alacritty "wifi"
    run_wifi
    ;;
  bluetooth)
    [[ "${force_tty}" == "--tty" || -t 1 ]] || open_in_alacritty "bluetooth"
    run_bluetooth
    ;;
  menu|--menu)
    [[ "${force_tty}" == "--tty" || -t 1 ]] || open_in_alacritty "menu"
    show_menu
    ;;
  *)
    printf 'Usage: %s [menu|wifi|bluetooth]\n' "$0" >&2
    exit 1
    ;;
esac
EOF

  chmod +x "${LOCAL_BIN}/terminal-modals"

  cat > "${LOCAL_BIN}/wifi-menu" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec "$HOME/.local/bin/terminal-modals" wifi "$@"
EOF

  chmod +x "${LOCAL_BIN}/wifi-menu"

  cat > "${LOCAL_BIN}/bluetooth-menu" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec "$HOME/.local/bin/terminal-modals" bluetooth "$@"
EOF

  chmod +x "${LOCAL_BIN}/bluetooth-menu"
}

write_polybar_features_config() {
  if [[ -f "${CONFIG_DIR}/polybar/features.ini" ]]; then
    return
  fi

  cat > "${CONFIG_DIR}/polybar/features.ini" <<'EOF'
# Polybar feature toggles (true/false/auto).
# Обязательные иконки wifi/bluetooth/settings включены всегда.

show_workspaces=true
show_window_title=true
show_current_desktop=true
show_layout=true
show_updates=true
show_audio=true
show_cpu=false
show_memory=false
show_network_text=false
show_bluetooth_text=false
show_battery=auto
show_date=true
show_tray=true
show_power=true
window_title_length=46
EOF
}

write_polybar_prepare_script() {
  cat > "${LOCAL_BIN}/polybar-prepare" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

user_file="${HOME}/.config/polybar/user.ini"
active_file="${HOME}/.config/polybar/user.active.ini"

mkdir -p "${HOME}/.config/polybar"
touch "${user_file}"

awk '
{
  lines[NR] = $0

  if (match($0, /^[[:space:]]*\[[^]]+\][[:space:]]*$/)) {
    section = $0
    gsub(/^[[:space:]]*\[/, "", section)
    gsub(/\][[:space:]]*$/, "", section)
    section = tolower(section)
    next
  }

  if (match($0, /^[[:space:]]*[A-Za-z0-9._-]+[[:space:]]*=/)) {
    key = $0
    sub(/^[[:space:]]*/, "", key)
    sub(/[[:space:]]*=.*/, "", key)
    key = tolower(key)

    idx = section SUBSEP key
    last[idx] = NR
    is_key[NR] = 1
    key_idx[NR] = idx
  }
}
END {
  for (i = 1; i <= NR; i++) {
    if (is_key[i] == 1 && last[key_idx[i]] != i) {
      continue
    }
    print lines[i]
  }
}
' "${user_file}" > "${active_file}.tmp"

mv "${active_file}.tmp" "${active_file}"
EOF

  chmod +x "${LOCAL_BIN}/polybar-prepare"
}

write_polybar_refresh_script() {
  cat > "${LOCAL_BIN}/polybar-refresh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

features_file="${HOME}/.config/polybar/features.ini"
config_file="${HOME}/.config/polybar/config.ini"

get_value() {
  local key="$1"
  local default="$2"
  local value=""

  if [[ -f "${features_file}" ]]; then
    value="$(
      awk -F= -v key="${key}" '
        $0 ~ /^[[:space:]]*#/ { next }
        NF < 2 { next }
        {
          k=$1
          gsub(/[[:space:]]/, "", k)
          if (tolower(k) == tolower(key)) {
            v=$2
            sub(/^[[:space:]]*/, "", v)
            sub(/[[:space:]]*$/, "", v)
            print tolower(v)
          }
        }
      ' "${features_file}" | tail -n 1
    )"
  fi

  [[ -n "${value}" ]] || value="${default}"
  printf '%s' "${value}"
}

set_ini_key() {
  local section="$1"
  local key="$2"
  local value="$3"
  local file="$4"
  local tmp_file

  tmp_file="$(mktemp)"

  awk -v target_section="${section}" -v target_key="${key}" -v target_value="${value}" '
    BEGIN {
      in_target = 0
      section_found = 0
      key_written = 0
    }

    function print_value() {
      printf "%s = %s\n", target_key, target_value
      key_written = 1
    }

    {
      line = $0

      if (match(line, /^[[:space:]]*\[[^]]+\][[:space:]]*$/)) {
        if (in_target && !key_written) {
          print_value()
        }

        section_name = line
        gsub(/^[[:space:]]*\[/, "", section_name)
        gsub(/\][[:space:]]*$/, "", section_name)

        if (tolower(section_name) == tolower(target_section)) {
          in_target = 1
          section_found = 1
        } else {
          in_target = 0
        }

        print line
        next
      }

      if (in_target && match(line, "^[[:space:]]*" target_key "[[:space:]]*=")) {
        if (!key_written) {
          print_value()
        }
        next
      }

      print line
    }

    END {
      if (!section_found) {
        print ""
        printf "[%s]\n", target_section
        print_value()
      } else if (in_target && !key_written) {
        print_value()
      }
    }
  ' "${file}" > "${tmp_file}"

  mv "${tmp_file}" "${file}"
}

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

modules_left=(launcher)
modules_center=()
modules_right=(wifi-icon bluetooth-icon control)

[[ "$(get_value show_workspaces true)" == "true" ]] && modules_left+=(bspwm)
[[ "$(get_value show_window_title true)" == "true" ]] && modules_center+=(xwindow)
[[ "$(get_value show_layout true)" == "true" ]] && modules_right=(layout "${modules_right[@]}")
[[ "$(get_value show_current_desktop true)" == "true" ]] && modules_right=(current-desktop "${modules_right[@]}")
[[ "$(get_value show_updates true)" == "true" ]] && modules_right+=(updates)
[[ "$(get_value show_audio true)" == "true" ]] && modules_right+=(pulseaudio)
[[ "$(get_value show_cpu false)" == "true" ]] && modules_right+=(cpu)
[[ "$(get_value show_memory false)" == "true" ]] && modules_right+=(memory)
[[ "$(get_value show_network_text false)" == "true" ]] && modules_right+=(network)
[[ "$(get_value show_bluetooth_text false)" == "true" ]] && modules_right+=(bluetooth)

battery_mode="$(get_value show_battery auto)"
if [[ "${battery_mode}" == "true" ]] || ([[ "${battery_mode}" == "auto" ]] && has_battery); then
  modules_right+=(battery)
fi

[[ "$(get_value show_date true)" == "true" ]] && modules_right+=(date)
[[ "$(get_value show_tray true)" == "true" ]] && modules_right+=(tray)
[[ "$(get_value show_power true)" == "true" ]] && modules_right+=(power)

if (( ${#modules_center[@]} == 0 )); then
  modules_center=(empty-center)
fi

title_len="$(get_value window_title_length 46)"
if ! [[ "${title_len}" =~ ^[0-9]+$ ]]; then
  title_len=46
fi
if (( title_len < 20 )); then
  title_len=20
fi
if (( title_len > 120 )); then
  title_len=120
fi

mkdir -p "${HOME}/.config/polybar"
touch "${config_file}"

set_ini_key "ui" "modules-left" "${modules_left[*]}" "${config_file}"
set_ini_key "ui" "modules-center" "${modules_center[*]}" "${config_file}"
set_ini_key "ui" "modules-right" "${modules_right[*]}" "${config_file}"
set_ini_key "module/xwindow" "label" "%title:0:${title_len}:...%" "${config_file}"

"${HOME}/.local/bin/launch-polybar" >/dev/null 2>&1 || true

if command -v notify-send >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
  notify-send "Polybar refreshed" "Обновил bar по ~/.config/polybar/features.ini"
fi
EOF

  chmod +x "${LOCAL_BIN}/polybar-refresh"
}

write_launcher_script() {
  cat > "${LOCAL_BIN}/open-app-launcher" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

exec rofi -show drun -theme "$HOME/.config/rofi/launcher.rasi"
EOF

  chmod +x "${LOCAL_BIN}/open-app-launcher"
}

write_open_file_manager_script() {
  cat > "${LOCAL_BIN}/open-file-manager" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: open-file-manager [--path DIR] [--select FILE]

Env:
  FILE_MANAGER=thunar|yazi|<custom binary>
USAGE
}

resolve_target() {
  local value="${1:-$HOME}"
  value="${value/#\~/$HOME}"
  realpath -m "${value}"
}

mode="path"
target="$HOME"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  --path)
    mode="path"
    target="$(resolve_target "${2:-$HOME}")"
    ;;
  --select)
    mode="select"
    target="$(resolve_target "${2:-$HOME}")"
    ;;
  "")
    ;;
  *)
    target="$(resolve_target "${1}")"
    ;;
esac

manager="${FILE_MANAGER:-thunar}"

if [[ "${manager}" == "thunar" ]]; then
  command -v thunar >/dev/null 2>&1 || {
    printf '[ERROR] thunar is not installed.\n' >&2
    exit 1
  }

  if [[ "${mode}" == "select" ]]; then
    exec thunar --select "${target}"
  fi
  exec thunar "${target}"
fi

if [[ "${manager}" == "yazi" ]]; then
  command -v yazi >/dev/null 2>&1 || {
    printf '[ERROR] yazi is not installed.\n' >&2
    exit 1
  }

  base="${target}"
  if [[ "${mode}" == "select" && -f "${target}" ]]; then
    base="$(dirname "${target}")"
  fi

  if command -v alacritty >/dev/null 2>&1; then
    exec alacritty -e yazi "${base}"
  fi
  exec yazi "${base}"
fi

command -v "${manager}" >/dev/null 2>&1 || {
  printf '[ERROR] FILE_MANAGER command not found: %s\n' "${manager}" >&2
  exit 1
}

if [[ "${mode}" == "select" ]]; then
  exec "${manager}" "${target}"
fi

exec "${manager}" "${target}"
EOF

  chmod +x "${LOCAL_BIN}/open-file-manager"
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

choices="$(
  printf '%s\n' \
    'Запуск приложений' \
    'Настройки приложений' \
    'Системные настройки' \
    'Polybar preset' \
    'Polybar custom' \
    'Применить настройки bar' \
    'Сменить тему' \
    'Сменить обои' \
    'Распаковать архив' \
    'Скриншот' \
    'Терминальные модалки' \
    'Приватные файлы (arch-access)' \
    'Обновить setup (auto-apply)' \
    'Перезапустить bar' \
    'Обновить систему' \
    'Меню питания'
)"

choice=""
if command -v rofi >/dev/null 2>&1; then
  choice="$(
    printf '%s\n' "${choices}" |
      rofi -dmenu -i -p "context" -theme "$HOME/.config/rofi/menu.rasi" || true
  )"
fi

if [[ -z "${choice}" ]] && command -v yad >/dev/null 2>&1; then
  choice="$(
    printf '%s\n' "${choices}" |
      yad --list \
        --title="Контекстное меню" \
        --class=BarContextMenu \
        --width=500 \
        --height=420 \
        --center \
        --column="Действие" \
        --separator="|" \
        --button="Открыть:0" \
        --button="Закрыть:1" 2>/dev/null || true
  )"
  choice="${choice%%|*}"
fi

case "${choice}" in
  "Запуск приложений") exec "$HOME/.local/bin/open-app-launcher" ;;
  "Настройки приложений") exec "$HOME/.local/bin/app-settings" ;;
  "Системные настройки") exec "$HOME/.local/bin/system-settings" ;;
  "Polybar preset") exec "$HOME/.local/bin/polybar-preset" ;;
  "Polybar custom") exec "$HOME/.local/bin/app-settings" panel-custom ;;
  "Применить настройки bar") exec "$HOME/.local/bin/polybar-refresh" ;;
  "Сменить тему") exec "$HOME/.local/bin/imba-theme" --pick ;;
  "Сменить обои") exec "$HOME/.local/bin/set-wallpaper" --pick ;;
  "Распаковать архив") exec "$HOME/.local/bin/extract-any" --pick ;;
  "Скриншот") exec "$HOME/.local/bin/take-screenshot" --pick ;;
  "Терминальные модалки") exec "$HOME/.local/bin/terminal-modals" menu ;;
  "Приватные файлы (arch-access)") exec "$HOME/.local/bin/arch-access" ;;
  "Обновить setup (auto-apply)") exec "$HOME/.local/bin/update-imba-script" ;;
  "Перезапустить bar") exec "$HOME/.local/bin/launch-polybar" ;;
  "Обновить систему") exec "$HOME/.local/bin/update-system" ;;
  "Меню питания") exec "$HOME/.local/bin/power-menu" ;;
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
    'Запуск приложений' \
    'Настройки приложений' \
    'Системные настройки' \
    'Сменить тему' \
    'Сменить обои' \
    'Распаковать архив' \
    'Скриншот' \
    'Терминальные модалки' \
    'Трекпад' \
    'Приватные файлы' \
    'Обновить setup (auto-apply)' \
    'Обновить систему' \
    'Меню питания' |
    rofi -dmenu -i -p "hub" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "Запуск приложений") exec "$HOME/.local/bin/open-app-launcher" ;;
  "Настройки приложений") exec "$HOME/.local/bin/app-settings" ;;
  "Системные настройки") exec "$HOME/.local/bin/system-settings" ;;
  "Сменить тему") exec "$HOME/.local/bin/imba-theme" --pick ;;
  "Сменить обои") exec "$HOME/.local/bin/set-wallpaper" --pick ;;
  "Распаковать архив") exec "$HOME/.local/bin/extract-any" --pick ;;
  "Скриншот") exec "$HOME/.local/bin/take-screenshot" --pick ;;
  "Терминальные модалки") exec "$HOME/.local/bin/terminal-modals" menu ;;
  "Трекпад") exec "$HOME/.local/bin/configure-input-devices" ;;
  "Приватные файлы") exec "$HOME/.local/bin/arch-access" ;;
  "Обновить setup (auto-apply)") exec "$HOME/.local/bin/update-imba-script" ;;
  "Обновить систему") exec "$HOME/.local/bin/update-system" ;;
  "Меню питания") exec "$HOME/.local/bin/power-menu" ;;
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
    'Заблокировать' \
    'Сон' \
    'Перезагрузить' \
    'Выключить' \
    'Выйти из bspwm' |
    rofi -dmenu -i -p "power" -theme "$HOME/.config/rofi/menu.rasi" || true
)"

case "${choice}" in
  "Заблокировать") exec "$HOME/.local/bin/lock-screen" ;;
  "Сон")
    "$HOME/.local/bin/lock-screen"
    sleep 0.8
    systemctl suspend
    ;;
  "Перезагрузить") systemctl reboot ;;
  "Выключить") systemctl poweroff ;;
  "Выйти из bspwm") bspc quit ;;
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
    panel-custom) open_terminal_editor "$HOME/.config/polybar/config.ini" ;;
    panel-features) open_terminal_editor "$HOME/.config/polybar/features.ini" ;;
    panel-preset) exec "$HOME/.local/bin/polybar-preset" ;;
    panel-refresh) exec "$HOME/.local/bin/polybar-refresh" ;;
    theme) exec "$HOME/.local/bin/imba-theme" --pick ;;
    archives) exec "$HOME/.local/bin/extract-any" --pick ;;
    screenshot) exec "$HOME/.local/bin/take-screenshot" --pick ;;
    launcher) open_terminal_editor "$HOME/.config/rofi/launcher.rasi" ;;
    notifications) open_terminal_editor "$HOME/.config/dunst/dunstrc" ;;
    compositor) open_terminal_editor "$HOME/.config/picom/picom.conf" ;;
    files) exec "$HOME/.local/bin/open-file-manager" --path "$HOME" ;;
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
    "Polybar Custom" "Ручная тонкая настройка bar в config.ini" \
    "Polybar Features" "Тогглы модулей через ~/.config/polybar/features.ini" \
    "Polybar Refresh" "Применить toggles и перезапустить bar" \
    "Polybar Preset" "Быстрый выбор профиля: focus/balanced/monitoring" \
    "Desktop Theme" "Переключить палитру интерфейса (bar/rofi/dunst)" \
    "Archive Extractor" "Распаковка zip/rar/7z/tar и других архивов" \
    "Screenshot" "Скриншот экрана, области или окна" \
    "Rofi Launcher" "Сетка приложений и quick hub" \
    "Dunst" "Уведомления и их оформление" \
    "Picom" "Сглаживание, тени и плавность" \
    "File Manager" "Открыть файловый менеджер (thunar/yazi/custom)" \
    --button="Открыть:0" \
    --button="Закрыть:1" || true
)"

selection="${choice%%|*}"

case "${selection}" in
  Firefox) open_target firefox ;;
  Alacritty) open_target terminal ;;
  Polybar) open_target panel ;;
  "Polybar Custom") open_target panel-custom ;;
  "Polybar Features") open_target panel-features ;;
  "Polybar Refresh") open_target panel-refresh ;;
  "Polybar Preset") open_target panel-preset ;;
  "Desktop Theme") open_target theme ;;
  "Archive Extractor") open_target archives ;;
  Screenshot) open_target screenshot ;;
  "Rofi Launcher") open_target launcher ;;
  Dunst) open_target notifications ;;
  Picom) open_target compositor ;;
  "File Manager") open_target files ;;
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
    network) exec "$HOME/.local/bin/wifi-menu" ;;
    bluetooth) exec "$HOME/.local/bin/bluetooth-menu" ;;
    audio) exec pavucontrol ;;
    display) exec arandr ;;
    display-layout) exec "$HOME/.local/bin/apply-monitor-layout" ;;
    layout) exec "$HOME/.local/bin/toggle-layout" ;;
    trackpad) exec "$HOME/.local/bin/configure-input-devices" ;;
    terminal-modals) exec "$HOME/.local/bin/terminal-modals" menu ;;
    bar) exec "$HOME/.local/bin/app-settings" panel ;;
    bar-refresh) exec "$HOME/.local/bin/polybar-refresh" ;;
    theme) exec "$HOME/.local/bin/imba-theme" --pick ;;
    archives) exec "$HOME/.local/bin/extract-any" --pick ;;
    appearance) exec lxappearance ;;
    wallpaper) exec "$HOME/.local/bin/set-wallpaper" --pick ;;
    screenshot) exec "$HOME/.local/bin/take-screenshot" --pick ;;
    avatar) exec "$HOME/.local/bin/set-user-avatar" --pick ;;
    ssh) exec "$HOME/.local/bin/bind-ssh-key" --pick ;;
    private-files) exec "$HOME/.local/bin/arch-access" ;;
    script-updates) exec "$HOME/.local/bin/update-imba-script" ;;
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
    "Обновить layout мониторов" "Переразложить рабочие столы для 2+ мониторов" \
    "Раскладка" "Сменить язык клавиатуры (EN/RU)" \
    "Терминальные модалки" "Wi-Fi/Bluetooth и другие меню в формате терминала" \
    "Трекпад" "Включить tap-to-click, natural scroll и libinput tweaks" \
    "Тема интерфейса" "Быстрое переключение готовых тем (ocean/sunset/forest/nord/graphite)" \
    "Обои" "Поставить свои обои и применить сразу" \
    "Архивы" "Распаковка zip/rar/7z/tar и других форматов" \
    "Скриншоты" "Снять весь экран, область или активное окно" \
    "Polybar" "Быстрая настройка bar и пресетов" \
    "Применить Polybar" "Прочитать features.ini и обновить bar" \
    "Внешний вид" "GTK-тема, иконки, курсор и шрифты" \
    "Аватар" "Фото пользователя для greeter и lock screen" \
    "SSH ключ" "Привязка SSH ключа к учётке и авто-agent" \
    "Приватные файлы" "Открыть защищённые пути через arch-access" \
    "Обновить setup" "Проверить обновления и автоматически применить script.sh" \
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
  "Обновить layout мониторов") open_target display-layout ;;
  Раскладка) open_target layout ;;
  "Терминальные модалки") open_target terminal-modals ;;
  Трекпад) open_target trackpad ;;
  "Тема интерфейса") open_target theme ;;
  Обои) open_target wallpaper ;;
  Архивы) open_target archives ;;
  Скриншоты) open_target screenshot ;;
  Polybar) open_target bar ;;
  "Применить Polybar") open_target bar-refresh ;;
  "Внешний вид") open_target appearance ;;
  Аватар) open_target avatar ;;
  "SSH ключ") open_target ssh ;;
  "Приватные файлы") open_target private-files ;;
  "Обновить setup") open_target script-updates ;;
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
  local max_len=14

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
  printf '󰈀 eth\n'
  exit 0
fi

printf '󰤮\n'
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/network-icon" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

active_wifi="$(
  nmcli -t -f IN-USE,SIGNAL dev wifi 2>/dev/null |
    awk -F: '$1=="*" {print $2; exit}' || true
)"
wired_state="$(
  nmcli -t -f TYPE,STATE dev status 2>/dev/null |
    awk -F: '$1=="ethernet" && $2=="connected" {print "yes"; exit}' || true
)"

if [[ -n "${active_wifi}" ]]; then
  signal="${active_wifi}"
  if (( signal >= 75 )); then
    printf '󰤨\n'
  elif (( signal >= 50 )); then
    printf '󰤥\n'
  elif (( signal >= 25 )); then
    printf '󰤢\n'
  else
    printf '󰤟\n'
  fi
  exit 0
fi

if [[ "${wired_state:-no}" == "yes" ]]; then
  printf '󰈀\n'
  exit 0
fi

printf '󰤮\n'
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/bluetooth-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

trim_label() {
  local label="$1"
  local max_len=12

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
  printf '󰂲\n'
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

printf '󰂯\n'
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/bluetooth-icon" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

powered="$(
  bluetoothctl show 2>/dev/null |
    awk -F': ' '/Powered:/ {print $2; exit}' || true
)"

if [[ "${powered:-no}" != "yes" ]]; then
  printf '󰂲\n'
  exit 0
fi

connected="$(
  bluetoothctl devices Connected 2>/dev/null |
    head -n 1 || true
)"

if [[ -n "${connected}" ]]; then
  printf '󰂱\n'
  exit 0
fi

printf '󰂯\n'
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

  cat > "${CONFIG_DIR}/polybar/scripts/layout-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v setxkbmap >/dev/null 2>&1; then
  printf '⌨ --\n'
  exit 0
fi

layout="$(
  setxkbmap -query 2>/dev/null |
    awk '/layout:/ {print $2; exit}' |
    cut -d',' -f1 |
    tr '[:upper:]' '[:lower:]'
)"

case "${layout}" in
  ru) printf '⌨ RU\n' ;;
  ua) printf '⌨ UA\n' ;;
  *) printf '⌨ EN\n' ;;
esac
EOF

  cat > "${CONFIG_DIR}/polybar/scripts/updates-status" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! command -v checkupdates >/dev/null 2>&1; then
  printf '󰄬\n'
  exit 0
fi

count="$(checkupdates 2>/dev/null | wc -l | tr -d ' ' || true)"

if [[ -z "${count}" || "${count}" == "0" ]]; then
  printf '󰄬\n'
  exit 0
fi

printf '󰏗 %s\n' "${count}"
EOF

  chmod +x \
    "${CONFIG_DIR}/polybar/scripts/network-status" \
    "${CONFIG_DIR}/polybar/scripts/network-icon" \
    "${CONFIG_DIR}/polybar/scripts/bluetooth-status" \
    "${CONFIG_DIR}/polybar/scripts/bluetooth-icon" \
    "${CONFIG_DIR}/polybar/scripts/current-desktop-status" \
    "${CONFIG_DIR}/polybar/scripts/layout-status" \
    "${CONFIG_DIR}/polybar/scripts/updates-status"
}

write_polybar_user_config() {
  if [[ -f "${CONFIG_DIR}/polybar/user.ini" ]]; then
    warn "Polybar user.ini уже существует, оставляю как есть (файл не обязателен для запуска bar)."
    return
  fi

  cat > "${CONFIG_DIR}/polybar/user.ini" <<'EOF'
; Пользовательский файл заметок для Polybar.
; Актуальные настройки bar:
;   ~/.config/polybar/config.ini
; ~/.config/polybar/features.ini
; ~/.local/bin/polybar-refresh
;
; Быстрый выбор профиля:
; ~/.local/bin/polybar-preset
;
; Важно: чтобы не ловить duplicate keys, не дублируй [ui] и [module/xwindow]
; в include-файлах. Меняй эти параметры в config.ini или через features.ini.
EOF
}

write_polybar_fallback_config() {
  cat > "${CONFIG_DIR}/polybar/fallback.ini" <<'EOF'
[bar/main]
width = 100%
height = 30
radius = 0
background = #101418
foreground = #F5F7FA
border-size = 0
padding-left = 1
padding-right = 1
module-margin = 1
font-0 = JetBrainsMono Nerd Font:size=10;2
font-1 = Noto Color Emoji:size=10;1
modules-left = launcher bspwm
modules-center = xwindow
modules-right = layout wifi-icon bluetooth-icon control pulseaudio date power
wm-restack = bspwm
enable-ipc = true
cursor-click = pointer
cursor-scroll = ns-resize

[module/launcher]
type = custom/text
content = 󰣇
content-padding = 1
content-foreground = #8FB9FF
click-left = ~/.local/bin/open-app-launcher

[module/bspwm]
type = internal/bspwm
pin-workspaces = true
enable-click = true
enable-scroll = false
label-focused = %name%
label-focused-background = #84D8C2
label-focused-foreground = #101418
label-focused-padding = 1
label-occupied = %name%
label-occupied-padding = 1
label-empty =
label-urgent = %name%
label-urgent-padding = 1

[module/xwindow]
type = internal/xwindow
label = %title:0:52:...%
label-empty = workspace

[module/wifi-icon]
type = custom/script
exec = ~/.config/polybar/scripts/network-icon
interval = 5
format-padding = 1
click-left = ~/.local/bin/wifi-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/wifi-menu

[module/bluetooth-icon]
type = custom/script
exec = ~/.config/polybar/scripts/bluetooth-icon
interval = 8
format-padding = 1
click-left = ~/.local/bin/bluetooth-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/bluetooth-menu

[module/layout]
type = custom/script
exec = ~/.config/polybar/scripts/layout-status
interval = 1
format-padding = 1
click-left = ~/.local/bin/toggle-layout
click-right = ~/.local/bin/bar-context-menu

[module/control]
type = custom/text
content = 󰒓
content-padding = 1
content-foreground = #F3C782
click-left = ~/.local/bin/control-center
click-right = ~/.local/bin/bar-context-menu

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <label-volume>
format-volume-padding = 1
format-muted = <label-muted>
format-muted-padding = 1
label-volume = 󰕾 %percentage%%
label-muted = 󰝟
click-right = ~/.local/bin/bar-context-menu
click-middle = pavucontrol

[module/date]
type = internal/date
interval = 5
date = %a %d
time = %H:%M
label = 󰥔 %time% · %date%
format-padding = 1

[module/power]
type = custom/text
content = 󰐥
content-padding = 1
content-foreground = #F49BB4
click-left = ~/.local/bin/power-menu
click-right = ~/.local/bin/bar-context-menu
EOF
}

write_polybar_preset_script() {
  cat > "${LOCAL_BIN}/polybar-preset" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

features_file="${HOME}/.config/polybar/features.ini"
preset="${1:-}"

if [[ -z "${preset}" ]]; then
  preset="$(
    printf '%s\n' "balanced" "focus" "monitoring" |
      rofi -dmenu -i -p "bar preset" -theme "$HOME/.config/rofi/menu.rasi" || true
  )"
fi

set_feature() {
  local key="$1"
  local value="$2"
  local tmp_file

  mkdir -p "$(dirname "${features_file}")"
  touch "${features_file}"
  tmp_file="$(mktemp)"

  awk -F= -v target_key="${key}" -v target_value="${value}" '
    BEGIN {
      written = 0
    }
    {
      if ($0 ~ /^[[:space:]]*#/ || NF < 2) {
        print $0
        next
      }

      key = $1
      gsub(/[[:space:]]/, "", key)

      if (tolower(key) == tolower(target_key)) {
        if (!written) {
          printf "%s=%s\n", target_key, target_value
          written = 1
        }
        next
      }

      print $0
    }
    END {
      if (!written) {
        printf "%s=%s\n", target_key, target_value
      }
    }
  ' "${features_file}" > "${tmp_file}"

  mv "${tmp_file}" "${features_file}"
}

case "${preset}" in
  balanced)
    set_feature show_workspaces true
    set_feature show_window_title true
    set_feature show_current_desktop true
    set_feature show_layout true
    set_feature show_updates true
    set_feature show_audio true
    set_feature show_cpu false
    set_feature show_memory false
    set_feature show_network_text false
    set_feature show_bluetooth_text false
    set_feature show_battery auto
    set_feature show_date true
    set_feature show_tray true
    set_feature show_power true
    set_feature window_title_length 46
    ;;
  focus)
    set_feature show_workspaces true
    set_feature show_window_title true
    set_feature show_current_desktop false
    set_feature show_layout true
    set_feature show_updates false
    set_feature show_audio true
    set_feature show_cpu false
    set_feature show_memory false
    set_feature show_network_text false
    set_feature show_bluetooth_text false
    set_feature show_battery auto
    set_feature show_date true
    set_feature show_tray false
    set_feature show_power true
    set_feature window_title_length 58
    ;;
  monitoring)
    set_feature show_workspaces true
    set_feature show_window_title true
    set_feature show_current_desktop true
    set_feature show_layout true
    set_feature show_updates true
    set_feature show_audio true
    set_feature show_cpu true
    set_feature show_memory true
    set_feature show_network_text false
    set_feature show_bluetooth_text false
    set_feature show_battery auto
    set_feature show_date true
    set_feature show_tray true
    set_feature show_power true
    set_feature window_title_length 40
    ;;
  *)
    exit 0
    ;;
esac

"$HOME/.local/bin/polybar-refresh" >/dev/null 2>&1 || true

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
pgrep -x xss-lock >/dev/null || xss-lock --transfer-sleep-lock -- "$HOME/.local/bin/lock-screen" &
"$HOME/.local/bin/configure-input-devices" >/dev/null 2>&1 || true

xsetroot -cursor_name left_ptr
xset s 300 300
xset dpms 600 660 720

"$HOME/.local/bin/apply-wallpaper" >/dev/null 2>&1 || true
"$HOME/.local/bin/apply-monitor-layout" >/dev/null 2>&1 || true

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

"$HOME/.local/bin/launch-polybar"
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

# bar context menu
super + ctrl + c
    ~/.local/bin/bar-context-menu

alt + ctrl + c
    ~/.local/bin/bar-context-menu

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

# apply polybar feature toggles
super + ctrl + p
    ~/.local/bin/polybar-refresh

alt + ctrl + p
    ~/.local/bin/polybar-refresh

# browser
super + b
    firefox

alt + b
    firefox

# file manager
super + e
    ~/.local/bin/open-file-manager

alt + e
    ~/.local/bin/open-file-manager

# set wallpaper
super + ctrl + w
    ~/.local/bin/set-wallpaper --pick

alt + ctrl + w
    ~/.local/bin/set-wallpaper --pick

# unpack archives
super + ctrl + x
    ~/.local/bin/extract-any --pick

alt + ctrl + x
    ~/.local/bin/extract-any --pick

# screenshots
Print
    ~/.local/bin/take-screenshot --full

shift + Print
    ~/.local/bin/take-screenshot --area

ctrl + Print
    ~/.local/bin/take-screenshot --window

super + shift + s
    ~/.local/bin/take-screenshot --area

alt + shift + s
    ~/.local/bin/take-screenshot --area

# switch desktop theme
super + ctrl + t
    ~/.local/bin/imba-theme --pick

alt + ctrl + t
    ~/.local/bin/imba-theme --pick

# switch keyboard layout
super + space
    ~/.local/bin/toggle-layout

alt + space
    ~/.local/bin/toggle-layout

# close focused window
super + q
    bspc node -c

alt + q
    bspc node -c

# lock screen
super + ctrl + l
    ~/.local/bin/lock-screen

alt + ctrl + l
    ~/.local/bin/lock-screen

# update system
super + shift + u
    ~/.local/bin/update-system

alt + shift + u
    ~/.local/bin/update-system

# update setup script
super + ctrl + u
    ~/.local/bin/update-imba-script

alt + ctrl + u
    ~/.local/bin/update-imba-script

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

# re-apply monitor layout for multi-monitor setups
super + ctrl + m
    ~/.local/bin/apply-monitor-layout; ~/.local/bin/launch-polybar

alt + ctrl + m
    ~/.local/bin/apply-monitor-layout; ~/.local/bin/launch-polybar

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

# brightness (Fn + F-keys on most laptops)
XF86MonBrightnessUp
    brightnessctl set +7%

XF86MonBrightnessDown
    brightnessctl set 7%-

XF86KbdBrightnessUp
    brightnessctl -d '*kbd_backlight*' set +1 || true

XF86KbdBrightnessDown
    brightnessctl -d '*kbd_backlight*' set 1- || true

# media (Fn + F-keys on many laptops)
XF86AudioPlay
    playerctl play-pause || true

XF86AudioNext
    playerctl next || true

XF86AudioPrev
    playerctl previous || true

XF86AudioStop
    playerctl stop || true
EOF
}

write_polybar_config() {
  cat > "${CONFIG_DIR}/polybar/config.ini" <<EOF
[settings]
screenchange-reload = true
pseudo-transparency = true

[colors]
background = #D80C1118
surface = #EB131A23
surface-alt = #F018212B
foreground = #ECF2F8
muted = #8EA0B2
primary = #84D8C2
secondary = #F3C782
accent = #8FB9FF
alert = #F49BB4
border = #22303D

[ui]
width = 100%
offset-x = 0
offset-y = 0
height = 34
radius = 0
padding-left = 1
padding-right = 1
module-margin = 0
font-main = JetBrainsMono Nerd Font:size=10;2
font-emoji = Noto Color Emoji:size=9;1
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
line-size = 2
line-color = \${colors.primary}
padding-left = \${ui.padding-left}
padding-right = \${ui.padding-right}
module-margin = \${ui.module-margin}
separator =
wm-restack = bspwm
enable-ipc = true
fixed-center = true
cursor-click = pointer
cursor-scroll = ns-resize
font-0 = \${ui.font-main}
font-1 = \${ui.font-emoji}
modules-left = \${ui.modules-left}
modules-center = \${ui.modules-center}
modules-right = \${ui.modules-right}
scroll-up = bspc desktop -f prev.local
scroll-down = bspc desktop -f next.local

[module/launcher]
type = custom/text
content = 󰣇
content-background = \${colors.surface-alt}
content-foreground = \${colors.accent}
content-padding = 1
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
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
label-focused = %name%
label-focused-background = \${colors.primary}
label-focused-foreground = #0d1116
label-focused-padding = 1
label-focused-margin = 1
label-occupied = %name%
label-occupied-background = transparent
label-occupied-foreground = \${colors.muted}
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
format-background = \${colors.surface}
format-foreground = \${colors.secondary}
format-padding = 1
click-right = ~/.local/bin/bar-context-menu

[module/layout]
type = custom/script
exec = ~/.config/polybar/scripts/layout-status
interval = 1
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
click-left = ~/.local/bin/toggle-layout
click-right = ~/.local/bin/bar-context-menu

[module/xwindow]
type = internal/xwindow
format-background = \${colors.surface-alt}
format-foreground = \${colors.foreground}
format-padding = 1
label = %title:0:46:...%
label-empty = workspace
label-empty-foreground = \${colors.muted}
click-right = ~/.local/bin/bar-context-menu

[module/empty-center]
type = custom/text
content =
content-background = \${colors.surface-alt}
content-foreground = \${colors.foreground}
content-padding = 0

[module/updates]
type = custom/script
exec = ~/.config/polybar/scripts/updates-status
interval = 600
format-background = \${colors.surface}
format-foreground = \${colors.accent}
format-padding = 1
click-left = ~/.local/bin/update-system
click-right = ~/.local/bin/bar-context-menu

[module/wifi-icon]
type = custom/script
exec = ~/.config/polybar/scripts/network-icon
interval = 5
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
click-left = ~/.local/bin/wifi-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/wifi-menu

[module/bluetooth-icon]
type = custom/script
exec = ~/.config/polybar/scripts/bluetooth-icon
interval = 8
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
click-left = ~/.local/bin/bluetooth-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/bluetooth-menu

[module/cpu]
type = internal/cpu
interval = 2
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
label = 󰍛 %percentage%%

[module/memory]
type = internal/memory
interval = 5
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
label = 󰘚 %percentage_used%%

[module/pulseaudio]
type = internal/pulseaudio
format-volume = <label-volume>
format-volume-background = \${colors.surface}
format-volume-foreground = \${colors.foreground}
format-volume-padding = 1
format-muted = <label-muted>
format-muted-background = \${colors.surface}
format-muted-foreground = \${colors.muted}
format-muted-padding = 1
label-volume = 󰕾 %percentage%%
label-muted = 󰝟
click-right = ~/.local/bin/bar-context-menu
click-middle = pavucontrol

[module/network]
type = custom/script
exec = ~/.config/polybar/scripts/network-status
interval = 5
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
click-left = ~/.local/bin/wifi-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/wifi-menu

[module/bluetooth]
type = custom/script
exec = ~/.config/polybar/scripts/bluetooth-status
interval = 8
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
click-left = ~/.local/bin/bluetooth-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/bluetooth-menu

[module/battery]
type = internal/battery
battery = ${BATTERY_NAME}
adapter = ${AC_NAME}
full-at = 99
low-at = 15
poll-interval = 10
format-charging-background = \${colors.surface}
format-charging-foreground = \${colors.foreground}
format-charging-padding = 1
format-discharging-background = \${colors.surface}
format-discharging-foreground = \${colors.foreground}
format-discharging-padding = 1
format-full-background = \${colors.surface}
format-full-foreground = \${colors.foreground}
format-full-padding = 1
format-low-background = \${colors.surface}
format-low-foreground = \${colors.alert}
format-low-padding = 1
format-charging = <label-charging>
format-discharging = <label-discharging>
format-full = <label-full>
format-low = <label-low>
label-charging = ⚡ %percentage%%
label-discharging = 🔋 %percentage%%
label-full = 🔋 %percentage%%
label-low = 🪫 %percentage%%

[module/date]
type = internal/date
interval = 5
date = %a %d
time = %H:%M
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
label = 󰥔 %time% · %date%
click-right = ~/.local/bin/bar-context-menu

[module/control]
type = custom/text
content = 󰒓
content-background = \${colors.surface}
content-foreground = \${colors.secondary}
content-padding = 1
click-left = ~/.local/bin/control-center
click-right = ~/.local/bin/bar-context-menu

[module/power]
type = custom/text
content = 󰐥
content-background = \${colors.surface-alt}
content-foreground = \${colors.alert}
content-padding = 1
click-left = ~/.local/bin/power-menu
click-right = ~/.local/bin/bar-context-menu
click-middle = ~/.local/bin/lock-screen

[module/tray]
type = internal/tray
format-background = \${colors.surface}
format-foreground = \${colors.foreground}
format-padding = 1
tray-spacing = 6
tray-size = 58%
EOF
}

write_alacritty_config() {
  cat > "${CONFIG_DIR}/alacritty/alacritty.toml" <<'EOF'
[window]
opacity = 0.94
padding = { x = 18, y = 16 }
decorations = "None"
dynamic_padding = true

[font]
normal = { family = "JetBrainsMono Nerd Font", style = "Regular" }
bold = { family = "JetBrainsMono Nerd Font", style = "Bold" }
italic = { family = "JetBrainsMono Nerd Font", style = "Italic" }
size = 11.5
offset = { x = 0, y = 1 }
glyph_offset = { x = 0, y = 0 }

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
  lines: 8;
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
    "${SHOTS_DIR}" \
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
  echo "3. Если хочешь поставить свои обои:"
  echo "   ~/.local/bin/set-wallpaper --pick"
  echo
  echo "4. Если хочешь распаковать архив:"
  echo "   ~/.local/bin/extract-any --pick"
  echo
  echo "5. Если нужен ручной твик трекпада:"
  echo "   ~/.local/bin/configure-input-devices"
  echo
  echo "6. Если хочешь сделать скриншот:"
  echo "   ~/.local/bin/take-screenshot --pick"
  echo
  echo "7. Если хочешь быстро сменить тему:"
  echo "   ~/.local/bin/imba-theme --pick"
  echo
  echo "8. Если хочешь переключить раскладку вручную:"
  echo "   ~/.local/bin/toggle-layout"
  echo
  echo "9. Терминальные модалки (Wi-Fi/Bluetooth/и т.д.):"
  echo "   ~/.local/bin/terminal-modals menu"
  echo
  echo "10. Если хочешь привязать свой SSH ключ вручную:"
  echo "   ~/.local/bin/bind-ssh-key --pick"
  echo
  echo "11. Доступ к приватным файлам:"
  echo "   ~/.local/bin/arch-access"
  echo
  echo "12. Обновление самого setup-скрипта:"
  echo "   ~/.local/bin/update-imba-script"
  echo
  echo "13. Кастомизация bar без ломки core:"
  echo "   ~/.config/polybar/config.ini"
  echo "   ~/.config/polybar/features.ini"
  echo "   ~/.local/bin/polybar-refresh"
  echo "   ~/.local/bin/polybar-preset"
  echo
  echo "14. Перезагрузи систему:"
  echo "   sudo reboot"
  echo
  echo "15. Главные хоткеи:"
  echo "   Alt+Return         -> терминал в тайлинге"
  echo "   Alt+Shift+Return   -> ещё один терминал"
  echo "   Alt+d              -> App Deck / выбор приложений"
  echo "   Alt+c              -> quick hub"
  echo "   Alt+Ctrl+c         -> контекстное меню bar"
  echo "   Alt+s              -> системные настройки"
  echo "   Alt+,              -> настройки приложений"
  echo "   Alt+Shift+p        -> меню питания"
  echo "   Alt+Ctrl+p         -> применить Polybar (features.ini)"
  echo "   Alt+b              -> Firefox"
  echo "   Alt+e              -> File Manager"
  echo "   Alt+q              -> закрыть окно"
  echo "   Alt+Ctrl+b         -> перезапуск bar"
  echo "   Alt+Ctrl+a         -> arch-access (приватные файлы)"
  echo "   Alt+Ctrl+u         -> обновить setup-скрипт"
  echo "   Alt+Ctrl+w         -> сменить обои"
  echo "   Alt+Ctrl+x         -> распаковать архив"
  echo "   Print              -> скриншот всего экрана"
  echo "   Shift+Print        -> скриншот выделенной области"
  echo "   Ctrl+Print         -> скриншот активного окна"
  echo "   Alt+Space          -> сменить раскладку"
  echo "   XF86MonBrightness  -> управление яркостью (Fn)"
  echo "   XF86AudioPlay/Next -> медиа-клавиши (Fn)"
  echo "   Alt+Ctrl+t         -> сменить тему интерфейса"
  echo "   Alt+Ctrl+m         -> обновить layout мониторов + bar"
  echo "   Alt+Ctrl+l         -> кастомный lock screen (imba)"
  echo "   Alt+Shift+u        -> обновление системы"
  echo
  echo "Верхняя панель теперь ближе к macOS-стилю: обязательные иконки Wi-Fi/Bluetooth/Settings плюс кастомизируемые модули."
  echo "Что показывать в bar можно выбрать через ~/.config/polybar/features.ini и применить ~/.local/bin/polybar-refresh."
  echo "Через ~/.local/bin/polybar-preset можно моментально включить monitoring-профиль с CPU/RAM."
  echo "Распаковка архивов: ~/.local/bin/extract-any (zip/rar/7z/tar и другие форматы)."
  echo "Темы интерфейса переключаются через ~/.local/bin/imba-theme (ocean/sunset/forest/nord/graphite)."
  echo "Скриншоты: ~/.local/bin/take-screenshot (--full/--area/--window/--pick)."
  echo "Правый клик по ключевым модулям bar открывает новое контекстное меню."
  echo "Сессия теперь поднимается через LightDM: есть greeter, поля логина/пароля и аватар пользователя."
  echo "Столы в баре ужаты до цифр, а активный рабочий стол вынесен отдельным индикатором справа."
  echo "Если bar не поднялся, смотри лог: ~/.cache/polybar/main.log"
  echo "Если основной config сломан, launch-polybar автоматически включит fallback: ~/.config/polybar/fallback.ini"
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
  write_script_source_marker
  write_lock_screen
  write_dropdown_terminal
  write_launch_polybar_script
  write_update_script
  write_self_update_script
  write_wallpaper_scripts
  write_extract_script
  write_screenshot_script
  write_monitor_layout_script
  write_input_devices_script
  write_layout_scripts
  write_terminal_modals_script
  write_theme_script
  write_launcher_script
  write_open_file_manager_script
  write_arch_access_script
  write_bar_context_menu_script
  write_control_center_script
  write_power_menu_script
  write_polybar_features_config
  write_polybar_refresh_script
  write_polybar_preset_script
  write_avatar_script
  write_ssh_key_script
  write_app_settings_script
  write_system_settings_script
  write_polybar_scripts
  write_polybar_user_config
  write_polybar_fallback_config
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
  "${LOCAL_BIN}/polybar-refresh" >/dev/null 2>&1 || true
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

  info "Применение твиков трекпада"
  "${LOCAL_BIN}/configure-input-devices" >/dev/null 2>&1 || true
  done_msg "Твики трекпада применены."

  start_polybar_now

  print_next_steps
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
