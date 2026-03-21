#!/usr/bin/env bash
set -euo pipefail

phase_generate_ui_assets() {
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
  write_launcher_script
  write_open_file_manager_script
  write_bar_context_menu_script
  write_control_center_script
  write_power_menu_script
  write_app_settings_script
  write_system_settings_script
  write_bspwm_config
  write_sxhkd_config
  write_x_profile
  write_x_session
}

phase_display_manager_setup() {
  configure_display_manager
}

phase_apply_input_tweaks() {
  info "Применение твиков трекпада"
  "${LOCAL_BIN}/configure-input-devices" >/dev/null 2>&1 || true
  done_msg "Твики трекпада применены."
}

phase_start_session_ui() {
  start_polybar_now
  print_next_steps
}
