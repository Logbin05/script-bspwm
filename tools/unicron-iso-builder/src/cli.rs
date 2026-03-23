use std::ffi::OsString;
use std::path::{Path, PathBuf};

use crate::config::Config;
use crate::git_helpers::normalize_repo_url;

pub fn parse_args(args: &[OsString], cfg: &mut Config) -> Result<(), String> {
    let mut i = 0usize;
    while i < args.len() {
        let key = args[i].to_string_lossy();
        match key.as_ref() {
            "--repo-url" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "--repo-url requires a value".to_string())?;
                cfg.repo_url = normalize_repo_url(&val.to_string_lossy());
            }
            "--repo-ref" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "--repo-ref requires a value".to_string())?;
                cfg.repo_ref = val.to_string_lossy().to_string();
            }
            "--archiso-base" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "--archiso-base requires a value".to_string())?;
                cfg.archiso_base = PathBuf::from(val);
            }
            "--workdir" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "--workdir requires a value".to_string())?;
                cfg.workdir = PathBuf::from(val);
            }
            "--outdir" => {
                i += 1;
                let val = args
                    .get(i)
                    .ok_or_else(|| "--outdir requires a value".to_string())?;
                cfg.outdir = PathBuf::from(val);
            }
            "--clean" => cfg.clean = true,
            "-h" | "--help" => {}
            _ => return Err(format!("Unknown option: {key}")),
        }
        i += 1;
    }
    Ok(())
}

pub fn is_help_requested(args: &[OsString]) -> bool {
    args.iter().any(|arg| {
        let s = arg.to_string_lossy();
        s == "-h" || s == "--help"
    })
}

pub fn print_help() {
    println!(
        "Usage: cargo run --manifest-path tools/unicron-iso-builder/Cargo.toml -- [options]

Options:
  --repo-url URL        Git URL embedded into ISO bootstrap
  --repo-ref REF        Git branch/tag embedded into ISO bootstrap
  --archiso-base DIR    archiso releng profile path (default: /usr/share/archiso/configs/releng)
  --workdir DIR         Working directory (default: <repo>/.build/iso)
  --outdir DIR          Output directory (default: <repo>/dist)
  --clean               Remove previous work/output before build
  -h, --help            Show this help

Examples:
  cargo run --manifest-path tools/unicron-iso-builder/Cargo.toml -- --clean
  cargo run --manifest-path tools/unicron-iso-builder/Cargo.toml -- --repo-ref dev"
    );
}

pub fn find_repo_root(start: &Path) -> Option<PathBuf> {
    let mut cur = Some(start);
    while let Some(path) = cur {
        if path.join("iso").is_dir() && path.join("lib").is_dir() {
            return Some(path.to_path_buf());
        }
        cur = path.parent();
    }
    None
}
