{ ... }:
{
  # Prevent replacing the running kernel image at runtime.
  security.protectKernelImage = true;

  # Enable the kernel audit subsystem (syscall/event logging).
  security.auditd.enable = true;
  boot.kernelParams = [ "audit=1" ];

  boot.kernel.sysctl = {
    # ---- Network: disable ICMP redirects ----
    # Redirects can be abused to reroute traffic through an attacker-controlled
    # gateway. No legitimate use case on a single-homed VPS.
    "net.ipv4.conf.all.accept_redirects"     = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects"     = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects"     = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    "net.ipv4.conf.all.send_redirects"       = 0;
    "net.ipv4.conf.default.send_redirects"   = 0;

    # ---- Network: disable source routing ----
    # Allows a sender to specify the route a packet takes — almost always
    # an attack vector.
    "net.ipv4.conf.all.accept_source_route"      = 0;
    "net.ipv4.conf.default.accept_source_route"  = 0;
    "net.ipv6.conf.all.accept_source_route"      = 0;
    "net.ipv6.conf.default.accept_source_route"  = 0;

    # ---- Network: SYN flood protection ----
    "net.ipv4.tcp_syncookies" = 1;

    # ---- Network: log packets with impossible addresses ----
    "net.ipv4.conf.all.log_martians"     = 1;
    "net.ipv4.conf.default.log_martians" = 1;

    # ---- Network: ICMP ----
    # Drop broadcasts and ignore RFC-violating error responses.
    "net.ipv4.icmp_echo_ignore_broadcasts"       = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;

    # ---- Network: reverse path filtering ----
    # Drop packets that arrive on an interface they could not have originated
    # from (strict mode). Prevents IP spoofing.
    "net.ipv4.conf.all.rp_filter"     = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    # ---- Kernel: restrict /proc/kallsyms and %pK kernel pointer leaks ----
    "kernel.kptr_restrict" = 2;

    # ---- Kernel: restrict dmesg to root ----
    "kernel.dmesg_restrict" = 1;

    # ---- Kernel: disable magic SysRq key ----
    "kernel.sysrq" = 0;

    # ---- BPF: harden JIT and restrict unprivileged BPF ----
    # Unprivileged BPF programs can be used for privilege escalation.
    # Docker and NixOS itself do not require unprivileged BPF.
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden"          = 2;
  };
}
