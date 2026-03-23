use std::path::Path;
use std::process::Command;

use crate::process_helpers::run_cmd_capture;

pub fn git_is_repo(path: &Path) -> bool {
    run_cmd_capture(
        Command::new("git")
            .arg("-C")
            .arg(path)
            .arg("rev-parse")
            .arg("--is-inside-work-tree"),
    )
    .is_ok()
}

pub fn git_output(path: &Path, args: &[&str]) -> Result<Option<String>, String> {
    let mut cmd = Command::new("git");
    cmd.arg("-C").arg(path);
    for arg in args {
        cmd.arg(arg);
    }
    match run_cmd_capture(&mut cmd) {
        Ok(output) => {
            let value = output.trim().to_string();
            if value.is_empty() {
                Ok(None)
            } else {
                Ok(Some(value))
            }
        }
        Err(_) => Ok(None),
    }
}

pub fn normalize_repo_url(url: &str) -> String {
    if let Some(rest) = url.strip_prefix("git@github.com:") {
        return format!("https://github.com/{rest}");
    }
    url.to_string()
}
