{ config, ... }:
{
  assertions = [
    {
      assertion = !config.lab.privateConfig.isPlaceholder;
      message = ''
        The active private config is still the public placeholder template.
        Create a sibling nix-vps-private flake and point validation/build
        commands at it with NIX_VPS_PRIVATE_FLAKE.
      '';
    }
    {
      assertion = config.lab.adminAuthorizedKeys != [ ];
      message = "Set lab.adminAuthorizedKeys in the private flake before building or deploying.";
    }
  ];
}
