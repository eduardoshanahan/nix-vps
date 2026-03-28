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
  # registerBouncer.enable defaults to true when services.crowdsec.enable is
  # true — the bouncer API key is auto-provisioned via cscli, no manual
  # secret management required.
  services.crowdsec-firewall-bouncer.enable = true;
}
