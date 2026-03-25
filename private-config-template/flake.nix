{
  description = "Placeholder private config for nix-vps";

  outputs = { self, ... }: {
    nixosModules.default = import ./modules/shared.nix;
  };
}
