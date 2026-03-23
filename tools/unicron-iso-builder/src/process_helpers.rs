use std::env;
use std::ffi::OsString;
use std::io::{self, Write};
use std::process::Command;

pub fn run_cmd(cmd: &mut Command, err_msg: &str) -> Result<(), String> {
    let status = cmd.status().map_err(|e| format!("{err_msg}: {e}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("{err_msg}: exit status {status}"))
    }
}

pub fn run_cmd_capture(cmd: &mut Command) -> Result<String, String> {
    let output = cmd
        .output()
        .map_err(|e| format!("Command execution failed: {e}"))?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        return Err(format!("Command failed: {}", stderr.trim()));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

pub fn cmd_exists(name: &str) -> bool {
    Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {name} >/dev/null 2>&1"))
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

pub fn require_cmd(name: &str) -> Result<(), String> {
    if cmd_exists(name) {
        Ok(())
    } else {
        Err(format!("Command not found: {name}"))
    }
}

pub fn is_root() -> Result<bool, String> {
    let output = run_cmd_capture(Command::new("id").arg("-u"))?;
    Ok(output.trim() == "0")
}

pub fn reexec_with_sudo(raw_args: &[OsString]) -> Result<(), String> {
    if !cmd_exists("sudo") {
        return Err("Run this command as root (sudo required).".to_string());
    }
    info("Re-running with sudo (mkarchiso requires root)");
    let exe = env::current_exe().map_err(|e| format!("current_exe failed: {e}"))?;
    let status = Command::new("sudo")
        .arg(exe)
        .args(raw_args)
        .status()
        .map_err(|e| format!("Failed to run sudo: {e}"))?;

    if status.success() {
        std::process::exit(0);
    }
    Err(format!("sudo re-exec failed with status {status}"))
}

pub fn info(msg: &str) {
    let _ = writeln!(io::stdout(), "[INFO] {msg}");
}
