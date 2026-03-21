#!/usr/bin/env bash
set -euo pipefail

phase_prepare_workspace() {
  info "Создание директорий"
  create_directories
  done_msg "Папки готовы."

  info "Бэкап текущих конфигов"
  backup_existing_files
  done_msg "Бэкапы сохранены."
}

phase_install_core_packages() {
  install_packages
  enable_services
}

phase_finalize_system_setup() {
  info "fastfetch в bashrc"
  if append_fastfetch; then
    done_msg "fastfetch подключён."
  fi

  info "Права владельца"
  fix_permissions
  done_msg "Владельцы файлов выровнены."
}
