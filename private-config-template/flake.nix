{
  description = "Placeholder private config for nix-vps";

  outputs = {
    nixosModules.default = import ./modules/shared.nix;
  };
}
