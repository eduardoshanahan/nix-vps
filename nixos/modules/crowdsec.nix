{ ... }:
{
  services.crowdsec = {
    enable = true;

    # Keep threat detection rules up to date automatically.
    autoUpdateService = true;

    # Install the base Linux and SSH detection collections from the hub.
    # These cover SSH brute-force, credential stuffing, and common Linux
    # log patterns without requiring manual parser/scenario management.
    hub.collections = [
      "crowdsecurity/linux"
      "crowdsecurity/sshd"
    ];

    # Teach CrowdSec where to read logs from.
    # SSH logs are read directly from the systemd journal.
    localConfig.acquisitions = [
      {
        source = "journalctl";
        journalctl_filter = [ "_SYSTEMD_UNIT=sshd.service" ];
        labels.type = "syslog";
      }
    ];
  };

  # Enforce CrowdSec ban decisions via nftables.
  # The bouncer auto-registers with the local CrowdSec LAPI because
  # registerBouncer.enable defaults to true when services.crowdsec.enable
  # is true — no manual API key management required.
  services.crowdsec-firewall-bouncer = {
    enable = true;
    # mode is auto-detected: nftables when networking.nftables is the
    # active firewall backend (NixOS 24.11+ default), iptables otherwise.
  };
}
