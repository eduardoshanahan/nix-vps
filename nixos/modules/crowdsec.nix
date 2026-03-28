{ ... }:
{
  services.crowdsec = {
    enable = true;

    # Keep threat detection rules up to date automatically.
    autoUpdateService = true;

    # Install the base Linux and SSH detection collections from the hub.
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

    # Enable the local LAPI so the agent can register itself and the
    # firewall bouncer can authenticate. Without this, api.server.enable
    # defaults to false, the setup script skips machine registration, and
    # the agent fails to start with "no API client section in configuration".
    settings.general.api.server.enable = true;

    # Path where cscli will write the machine credentials on first run.
    # The setup script creates this file when it does not yet exist.
    # Must be within ReadWritePaths of the crowdsec service (/etc/crowdsec/
    # or /var/lib/crowdsec/state/).
    settings.lapi.credentialsFile = "/var/lib/crowdsec/state/local_api_credentials.yaml";
  };

  # Enforce CrowdSec ban decisions via nftables.
  # registerBouncer.enable defaults to true when services.crowdsec.enable is
  # true — the bouncer API key is auto-provisioned via cscli, no manual
  # secret management required.
  services.crowdsec-firewall-bouncer.enable = true;
}
