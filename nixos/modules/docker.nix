{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker_28;
    daemon.settings = {
      "data-root" = "/srv/docker";
    };
  };

  systemd.tmpfiles.rules = [
    "d /srv/docker 0710 root root - -"
    "d /srv/compose 0750 root root - -"
  ];
}
