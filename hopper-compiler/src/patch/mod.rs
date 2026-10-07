#![allow(dead_code)]

mod patchelf;
#[cfg(target_os = "linux")]
mod e9;

pub use patchelf::*;
#[cfg(target_os = "linux")]
pub use e9::*;
