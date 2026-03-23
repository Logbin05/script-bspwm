use std::env;
use std::path::{Path, PathBuf};

use crate::git_helpers::{git_is_repo, git_output, normalize_repo_url};

pub const DEFAULT_REPO_URL: &str = "https://github.com/Logbin05/BSPWM-UNICRON.git";
pub const DEFAULT_REPO_REF: &str = "master";
pub const DEFAULT_ARCHISO_BASE: &str = "/usr/share/archiso/configs/releng";

#[derive(Debug, Clone)]
pub struct Config {
    pub repo_root: PathBuf,
    pub archiso_base: PathBuf,
    pub workdir: PathBuf,
    pub outdir: PathBuf,
    pub repo_url: String,
    pub repo_ref: String,
    pub clean: bool,
}

pub fn default_config(repo_root: &Path) -> Result<Config, String> {
    let mut repo_url = DEFAULT_REPO_URL.to_string();
    let mut repo_ref = DEFAULT_REPO_REF.to_string();

    if git_is_repo(repo_root) {
        if let Some(remote) = git_output(repo_root, &["remote", "get-url", "origin"])? {
            if !remote.is_empty() {
                repo_url = normalize_repo_url(&remote);
            }
        }
        if let Some(branch) = git_output(repo_root, &["rev-parse", "--abbrev-ref", "HEAD"])? {
            if !branch.is_empty() && branch != "HEAD" {
                repo_ref = branch;
            }
        }
    }

    let archiso_base = env::var("ARCHISO_BASE")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from(DEFAULT_ARCHISO_BASE));
    let workdir = env::var("WORKDIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| repo_root.join(".build/iso"));
    let outdir = env::var("OUTDIR")
        .map(PathBuf::from)
        .unwrap_or_else(|_| repo_root.join("dist"));

    Ok(Config {
        repo_root: repo_root.to_path_buf(),
        archiso_base,
        workdir,
        outdir,
        repo_url,
        repo_ref,
        clean: false,
    })
}
