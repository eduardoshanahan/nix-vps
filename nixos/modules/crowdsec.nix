{ config, pkgs, lib, ... }:
let
  format = pkgs.formats.yaml { };
  configFile = format.generate "crowdsec.yaml" config.services.crowdsec.settings.general;
in
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

  # Symlink the Nix-store-generated config to the standard path so the raw
  # cscli binary (used by crowdsec-firewall-bouncer-register.service via
  # lib.getExe') can find it. The NixOS module creates a systemPackages
  # wrapper with -c <store-path> for interactive use, but the bouncer-register
  # service calls the raw binary which defaults to /etc/crowdsec/config.yaml.
  systemd.tmpfiles.rules = [
    "L+ /etc/crowdsec/config.yaml - - - - ${configFile}"
  ];

  # Enforce CrowdSec ban decisions via nftables.
  # registerBouncer.enable defaults to true when services.crowdsec.enable is
  # true — the bouncer API key is auto-provisioned via cscli, no manual
  # secret management required.
  services.crowdsec-firewall-bouncer.enable = true;

  # The upstream bouncer-register service declares:
  #   DynamicUser = true
  #   StateDirectory = "crowdsec-firewall-bouncer-register crowdsec"
  # DynamicUser + StateDirectory causes systemd to migrate ALL listed dirs to
  # /var/lib/private/ with symlinks — including /var/lib/crowdsec which the
  # crowdsec agent's ProtectSystem bind-mount expects to be a real directory.
  # Remove crowdsec from StateDirectory and disable DynamicUser to keep
  # /var/lib/crowdsec as a normal directory owned by the crowdsec user.
  systemd.services.crowdsec-firewall-bouncer-register.serviceConfig = {
    DynamicUser = lib.mkForce false;
    StateDirectory = lib.mkForce "crowdsec-firewall-bouncer-register";
  };
}
