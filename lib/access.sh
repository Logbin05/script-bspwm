#!/usr/bin/env bash
set -euo pipefail

phase_generate_access_assets() {
  write_arch_access_script
  write_avatar_script
  write_ssh_key_script
}

phase_setup_access_runtime() {
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
}
