use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::process_helpers::run_cmd;

pub fn ensure_exists(path: &Path, what: &str) -> Result<(), String> {
    if path.exists() {
        Ok(())
    } else {
        Err(format!("{what} not found: {}", path.display()))
    }
}

pub fn remove_if_exists(path: &Path) -> Result<(), String> {
    if !path.exists() {
        return Ok(());
    }
    if path.is_dir() {
        fs::remove_dir_all(path).map_err(|e| format!("Failed to remove dir {}: {e}", path.display()))
    } else {
        fs::remove_file(path).map_err(|e| format!("Failed to remove file {}: {e}", path.display()))
    }
}

pub fn rsync_copy_dir(src: &Path, dst: &Path) -> Result<(), String> {
    if !src.is_dir() {
        return Err(format!("Source is not a directory: {}", src.display()));
    }
    fs::create_dir_all(dst)
        .map_err(|e| format!("Failed to create destination {}: {e}", dst.display()))?;
    let src_with_slash = format!("{}/", src.display());
    let dst_with_slash = format!("{}/", dst.display());
    run_cmd(
        Command::new("rsync")
            .arg("-a")
            .arg(src_with_slash)
            .arg(dst_with_slash),
        "rsync failed",
    )
}

pub fn append_unique_packages(base_file: &Path, add_file: &Path) -> Result<(), String> {
    let base = fs::read_to_string(base_file)
        .map_err(|e| format!("Failed to read {}: {e}", base_file.display()))?;
    let add = fs::read_to_string(add_file)
        .map_err(|e| format!("Failed to read {}: {e}", add_file.display()))?;

    let mut existing: HashSet<String> = base
        .lines()
        .map(str::trim)
        .filter(|line| !line.is_empty() && !line.starts_with('#'))
        .map(ToString::to_string)
        .collect();

    let mut merged = base;
    if !merged.ends_with('\n') {
        merged.push('\n');
    }

    for line in add.lines() {
        let pkg = line.trim();
        if pkg.is_empty() || pkg.starts_with('#') {
            continue;
        }
        if existing.insert(pkg.to_string()) {
            merged.push_str(pkg);
            merged.push('\n');
        }
    }

    fs::write(base_file, merged).map_err(|e| format!("Failed to write {}: {e}", base_file.display()))
}

pub fn write_profiledef(path: &Path) -> Result<(), String> {
    let content = r#"#!/usr/bin/env bash

iso_name="bspwm-unicron"
iso_label="BSPWM_UNICRON_$(date +%Y%m)"
iso_publisher="BSPWM-UNICRON <https://github.com/Logbin05/BSPWM-UNICRON>"
iso_application="BSPWM-UNICRON Custom Arch ISO"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
  'bios.syslinux.mbr'
  'bios.syslinux.eltorito'
  'uefi-ia32.systemd-boot.esp'
  'uefi-x64.systemd-boot.esp'
  'uefi-x64.systemd-boot.eltorito'
)
arch='x86_64'
pacman_conf='pacman.conf'
airootfs_image_type='squashfs'
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15')
file_permissions=(
  ["/root"]="0:0:750"
  ["/root/unicron-firststeps.sh"]="0:0:755"
  ["/usr/local/bin/unicron-bootstrap"]="0:0:755"
)
"#;
    fs::write(path, content).map_err(|e| format!("Failed to write {}: {e}", path.display()))
}

pub fn replace_placeholders(path: &Path, pairs: &[(&str, &str)]) -> Result<(), String> {
    let mut text = fs::read_to_string(path).map_err(|e| format!("Failed to read {}: {e}", path.display()))?;
    for (from, to) in pairs {
        text = text.replace(from, to);
    }
    fs::write(path, text).map_err(|e| format!("Failed to write {}: {e}", path.display()))
}

pub fn find_latest_iso(outdir: &Path) -> Result<Option<PathBuf>, String> {
    let mut candidates: Vec<PathBuf> = Vec::new();
    let entries = fs::read_dir(outdir)
        .map_err(|e| format!("Failed to read output dir {}: {e}", outdir.display()))?;
    for entry in entries {
        let entry = entry.map_err(|e| format!("read_dir entry error: {e}"))?;
        let path = entry.path();
        if !path.is_file() {
            continue;
        }
        let Some(name) = path.file_name().and_then(|n| n.to_str()) else {
            continue;
        };
        if name.starts_with("bspwm-unicron-") && name.ends_with(".iso") {
            candidates.push(path);
        }
    }
    candidates.sort();
    Ok(candidates.pop())
}
