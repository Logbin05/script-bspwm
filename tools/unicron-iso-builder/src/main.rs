mod builder;
mod cli;
mod config;
mod fs_helpers;
mod git_helpers;
mod process_helpers;

use std::process::ExitCode;

fn main() -> ExitCode {
    if let Err(err) = builder::run() {
        eprintln!("[ERROR] {err}");
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}
