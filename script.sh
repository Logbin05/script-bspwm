#!/usr/bin/env bash
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Keep source-dir pointing to repo root after splitting monolith into lib/.
export IMBA_SCRIPT_DIR="${SCRIPT_ROOT}"

source "${SCRIPT_ROOT}/lib/legacy.sh"
source "${SCRIPT_ROOT}/lib/packages.sh"
source "${SCRIPT_ROOT}/lib/theme.sh"
source "${SCRIPT_ROOT}/lib/ui.sh"
source "${SCRIPT_ROOT}/lib/access.sh"

main() {
  phase_prepare_workspace
  phase_install_core_packages

  info "Генерация helper-скриптов и конфигов"
  phase_generate_ui_assets
  phase_generate_theme_assets
  phase_generate_access_assets
  "${LOCAL_BIN}/polybar-refresh" >/dev/null 2>&1 || true
  done_msg "Новая тема и окружение записаны."

  phase_display_manager_setup
  phase_setup_access_runtime
  phase_finalize_system_setup
  phase_apply_input_tweaks
  phase_start_session_ui
}

main "$@"
