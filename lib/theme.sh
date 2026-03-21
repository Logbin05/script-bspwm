#!/usr/bin/env bash
set -euo pipefail

phase_generate_theme_assets() {
  write_script_source_marker
  write_theme_script

  write_polybar_features_config
  write_polybar_refresh_script
  write_polybar_preset_script
  write_polybar_scripts
  write_polybar_user_config
  write_polybar_fallback_config
  write_polybar_config

  write_alacritty_config
  write_picom_config
  write_dunst_config
  write_rofi_config
  write_gtk_config
}
