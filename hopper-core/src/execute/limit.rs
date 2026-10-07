//! Limitation of memory and time

pub trait SetLimit {
    /// Limit memory
    fn mem_limit(&mut self, size: Option<u64>) -> &mut Self;
    /// Dumping cores is slow and can lead to anomalies if SIGKILL is delivered
    /// before the dump is complete
    fn core_limit(&mut self) -> &mut Self;
    /// Isolate the process and configure standard descriptors.
    fn setsid(&mut self) -> &mut Self;
}

#[cfg(target_family = "unix")]
use std::{os::unix::process::CommandExt, process::Command};
#[cfg(target_family = "unix")]
impl SetLimit for Command {
    fn mem_limit(&mut self, size: Option<u64>) -> &mut Self {
        if let Some(size) = size {
            let func = move || {
                if size > 0 {
                    let size = size << 20;
                    // `rlim_t` is unsigned on Linux and macOS but signed on FreeBSD.
                    let mem_limit = size as libc::rlim_t;
                    let r = libc::rlimit {
                        rlim_cur: mem_limit,
                        rlim_max: mem_limit,
                    };
                    unsafe {
                        // FreeBSD's RLIMIT_DATA only covers the brk() heap, while its
                        // jemalloc allocates with mmap(), so limit the address space.
                        #[cfg(any(
                            target_os = "linux",
                            target_os = "macos",
                            target_os = "freebsd"
                        ))]
                        libc::setrlimit(libc::RLIMIT_AS, &r);
                        // This takes care of OpenBSD, which doesn't have RLIMIT_AS, but
                        // according to reliable sources, RLIMIT_DATA covers anonymous
                        // maps - so we should be getting good protection against OOM bugs
                        #[cfg(target_os = "openbsd")]
                        libc::setrlimit(libc::RLIMIT_DATA, &r);
                    }
                }
                Ok(())
            };
            return unsafe { self.pre_exec(func) };
        }
        self
    }

    fn setsid(&mut self) -> &mut Self {
        let func = move || {
            unsafe {
                libc::setsid();
            };
            Ok(())
        };
        unsafe { self.pre_exec(func) }
    }

    fn core_limit(&mut self) -> &mut Self {
        let func = move || {
            let r0 = libc::rlimit {
                rlim_cur: 0,
                rlim_max: 0,
            };
            unsafe {
                libc::setrlimit(libc::RLIMIT_CORE, &r0);
            };
            Ok(())
        };
        unsafe { self.pre_exec(func) }
    }
}

#[cfg(target_os = "windows")]
use std::process::Command;
#[cfg(target_os = "windows")]
impl SetLimit for Command {
    fn mem_limit(&mut self, _size: Option<u64>) -> &mut Self {
        self
    }

    fn setsid(&mut self) -> &mut Self {
        self
    }

    fn core_limit(&mut self) -> &mut Self {
        self
    }
}
