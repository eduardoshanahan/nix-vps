{ config, pkgs, ... }:
{
  networking.useDHCP = true;
  networking.domain = config.lab.domain;
  networking.wireless.enable = false;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  networking.dhcpcd.extraConfig = ''
    nohook hostname
  '';

  system.activationScripts.enforceTransientHostname.text = ''
    if [ -n "${config.networking.hostName}" ]; then
      ${pkgs.systemd}/bin/hostnamectl set-hostname "${config.networking.hostName}" --transient || true
    fi
  '';
}
