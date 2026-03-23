use std::env;
use std::ffi::OsString;
use std::fs;
use std::process::Command;

use crate::cli::{find_repo_root, is_help_requested, parse_args, print_help};
use crate::config::default_config;
use crate::fs_helpers::{
    append_unique_packages, ensure_exists, find_latest_iso, remove_if_exists, replace_placeholders,
    rsync_copy_dir, write_profiledef,
};
use crate::process_helpers::{info, is_root, reexec_with_sudo, require_cmd, run_cmd};

pub fn run() -> Result<(), String> {
    let raw_args: Vec<OsString> = env::args_os().skip(1).collect();

    if is_help_requested(&raw_args) {
        print_help();
        return Ok(());
    }

    let current_dir = env::current_dir().map_err(|e| format!("current_dir failed: {e}"))?;
    let repo_root = find_repo_root(&current_dir)
        .ok_or_else(|| "Cannot find repository root (expected iso/ and lib/ dirs).".to_string())?;

    let mut cfg = default_config(&repo_root)?;
    parse_args(&raw_args, &mut cfg)?;

    if !is_root()? {
        return reexec_with_sudo(&raw_args);
    }

    require_cmd("mkarchiso")?;
    require_cmd("rsync")?;
    require_cmd("git")?;

    let profile_dir = cfg.workdir.join("profile");
    let build_dir = cfg.workdir.join("work");
    let extra_packages_file = cfg.repo_root.join("iso/extra-packages.x86_64");
    let overlay_airootfs = cfg.repo_root.join("iso/airootfs");

    ensure_exists(&cfg.archiso_base, "archiso releng profile")?;
    ensure_exists(&extra_packages_file, "extra packages file")?;
    ensure_exists(&overlay_airootfs, "iso overlay")?;

    if cfg.clean {
        info(&format!(
            "Cleaning workdir/outdir: {} {}",
            cfg.workdir.display(),
            cfg.outdir.display()
        ));
        remove_if_exists(&cfg.workdir)?;
        remove_if_exists(&cfg.outdir)?;
    }

    fs::create_dir_all(&cfg.workdir)
        .map_err(|e| format!("Failed to create workdir {}: {e}", cfg.workdir.display()))?;
    fs::create_dir_all(&cfg.outdir)
        .map_err(|e| format!("Failed to create outdir {}: {e}", cfg.outdir.display()))?;

    info("Preparing archiso profile");
    remove_if_exists(&profile_dir)?;
    rsync_copy_dir(&cfg.archiso_base, &profile_dir)?;

    let profiledef_path = profile_dir.join("profiledef.sh");
    write_profiledef(&profiledef_path)?;

    info("Applying extra package layer");
    append_unique_packages(&profile_dir.join("packages.x86_64"), &extra_packages_file)?;

    info("Applying BSPWM-UNICRON overlay");
    rsync_copy_dir(&overlay_airootfs, &profile_dir.join("airootfs"))?;

    let replacements = [
        ("__UNICRON_REPO_URL__", cfg.repo_url.as_str()),
        ("__UNICRON_REPO_REF__", cfg.repo_ref.as_str()),
    ];

    replace_placeholders(
        &profile_dir.join("airootfs/usr/local/bin/unicron-bootstrap"),
        &replacements,
    )?;
    replace_placeholders(
        &profile_dir.join("airootfs/root/unicron-firststeps.sh"),
        &replacements,
    )?;
    replace_placeholders(&profile_dir.join("airootfs/etc/motd"), &replacements)?;

    info("Building ISO with mkarchiso (this can take a while)");
    run_cmd(
        Command::new("mkarchiso")
            .arg("-v")
            .arg("-w")
            .arg(&build_dir)
            .arg("-o")
            .arg(&cfg.outdir)
            .arg(&profile_dir),
        "mkarchiso build failed",
    )?;

    let iso = find_latest_iso(&cfg.outdir)?
        .ok_or_else(|| format!("Build finished but no ISO found in {}", cfg.outdir.display()))?;

    println!("\n[OK] ISO built: {}", iso.display());
    println!(
        "[OK] Bootstrap source: {} ({})",
        cfg.repo_url, cfg.repo_ref
    );

    Ok(())
}
