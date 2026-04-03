{ config, lib, ... }:
let
  admin = config.lab.adminUser;
  adminKeys = config.lab.adminAuthorizedKeys;
  keyText =
    if adminKeys == []
    then null
    else (builtins.concatStringsSep "\n" adminKeys) + "\n";
in
{
  services.openssh = {
    enable = true;
    settings = {
      # Key-only SSH policy for internet-exposed host.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey";
      PermitRootLogin = "no";
      AllowAgentForwarding = "no";
      X11Forwarding = false;
      UseDns = false;
      AllowUsers = [ admin ];
      LoginGraceTime = "30s";
      MaxAuthTries = 3;
      MaxSessions = 4;
      MaxStartups = "10:30:60";
      AuthorizedKeysFile = "/etc/ssh/authorized_keys/%u";
    };
  };

  users.allowNoPasswordLogin = true;

  environment.etc = lib.mkMerge [
    (lib.mkIf (keyText != null) {
      "ssh/authorized_keys/${admin}" = {
        text = keyText;
        mode = "0644";
      };
    })
  ];

  systemd.tmpfiles.rules = [
    "d /etc/ssh/authorized_keys 0755 root root -"
  ];
}
