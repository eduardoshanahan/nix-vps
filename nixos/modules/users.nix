{ config, lib, ... }:
let
  admin = config.lab.adminUser;
in
{
  users.users.${admin} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };
}
