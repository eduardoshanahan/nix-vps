{ lib, ... }:
{
  options.lab = {
    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Primary admin username.";
    };

    adminAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys for the primary admin user.";
      example = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... admin@laptop"
      ];
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "example.com";
      description = "Public domain used for Traefik routing.";
    };

    privateConfig = {
      source = lib.mkOption {
        type = lib.types.str;
        default = "private-config-template";
        description = "Human-readable description of the active private config source.";
      };

      isPlaceholder = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the active private config is still a placeholder template.";
      };
    };

    sops = {
      ageKeyFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/sops/age.key";
        description = "Path to the per-host age private key (must exist on the host; never in the Nix store).";
      };

      defaultSopsFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional default SOPS file path.";
      };
    };

    nix = {
      signingKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional local Nix store signing key file for this host.";
      };

      trustedPublicKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional trusted Nix signing public keys.";
      };
    };
  };
}
