{ ... }:
{
  imports = [
    ../disko/vps.nix
  ];

  networking.hostName = "vps-host";
}
