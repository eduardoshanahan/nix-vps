{
  description = "nix-vps dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    # nixpkgs-unstable provides crowdsec-firewall-bouncer and replace-secret,
    # which are not yet in nixos-25.05. The overlay below injects them into
    # the system pkgs so the upstream crowdsec NixOS modules can reference them.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nix-services.url = "git+ssh://git@gitea.internal.example:2222/eduardo/nix-services.git?ref=main";
    sops-nix.url = "github:Mic92/sops-nix";
    private.url = "git+ssh://git@gitea.internal.example:2222/eduardo/nix-vps-private.git?ref=main";
  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, flake-utils, disko, private, ... }:
    let
      lib = nixpkgs.lib;
      privateModuleOrNull = name: lib.attrByPath [ "nixosModules" name ] null private;

      mkBaseSystem = { profile, extraModules ? [], hostModule ? null, privateSharedModule ? null, privateHostModule ? null }:
        lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = {
            inherit inputs self;
            vpsRepoRoot = ./.;
            privateRepoRoot = inputs.private.outPath;
          };
          modules =
          [
            # Overlay packages that are in nixos-unstable but not nixos-25.05,
            # needed by the upstream crowdsec NixOS modules below.
            ({ pkgs, ... }: {
              nixpkgs.overlays = [
                (_final: _prev: {
                  crowdsec-firewall-bouncer = nixpkgs-unstable.legacyPackages.${pkgs.system}.crowdsec-firewall-bouncer;
                  replace-secret = nixpkgs-unstable.legacyPackages.${pkgs.system}.replace-secret;
                })
              ];
            })
            # Upstream crowdsec NixOS modules (not yet in nixos-25.05).
            "${nixpkgs-unstable}/nixos/modules/services/security/crowdsec.nix"
            "${nixpkgs-unstable}/nixos/modules/services/security/crowdsec-firewall-bouncer.nix"
            ./nixos/modules/options.nix
            ./nixos/modules/base.nix
            ./nixos/modules/users.nix
            ./nixos/modules/ssh.nix
            ./nixos/modules/docker.nix
            ./nixos/modules/network.nix
            ./nixos/modules/hardening.nix
            ./nixos/modules/crowdsec.nix
            inputs.sops-nix.nixosModules.sops
            ./nixos/modules/secrets.nix
            disko.nixosModules.disko
            profile
            ./nixos/modules/private.nix
            ./nixos/modules/validation.nix
          ]
          ++ (if hostModule != null then [ hostModule ] else [])
          ++ extraModules
          ++ (if privateSharedModule != null then [ privateSharedModule ] else [])
          ++ (if privateHostModule != null then [ privateHostModule ] else []);
        };

      privateSharedOverrides = privateModuleOrNull "default";
      maybePrivateHost = name: privateModuleOrNull name;
    in
    {
      nixosConfigurations = {
        vps-01 = mkBaseSystem {
          profile = ./nixos/profiles/vps.nix;
          hostModule = ./nixos/hosts/vps-01.nix;
          privateSharedModule = privateSharedOverrides;
          privateHostModule = maybePrivateHost "vps-01";
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        validatePrivateConfig = pkgs.writeShellApplication {
          name = "validate-private-config";
          runtimeInputs = [
            pkgs.jq
            pkgs.nix
          ];
          text = ''
            set -euo pipefail

            quiet=0

            usage() {
              cat >&2 <<'EOF'
            usage: validate-private-config [--quiet] [nixosConfiguration]

              --quiet  Only print failures.

            Validates that a real private flake exists and that path-based
            evaluation resolves the required private values.
            EOF
              exit 1
            }

            while [ "$#" -gt 0 ]; do
              case "$1" in
                --quiet)
                  quiet=1
                  shift
                  ;;
                --help|-h)
                  usage
                  ;;
                --*)
                  echo "unknown option: $1" >&2
                  usage
                  ;;
                *)
                  break
                  ;;
              esac
            done

            if [ "$#" -gt 1 ]; then
              usage
            fi

            node="''${1:-vps-01}"
            repo_flake_path="path:${self}"
            flake_ref="$repo_flake_path#nixosConfigurations.$node"
            private_flake_dir="''${NIX_VPS_PRIVATE_FLAKE:-$PWD/../nix-vps-private}"

            if [ ! -f "$private_flake_dir/flake.nix" ]; then
              cat >&2 <<EOF
            missing private flake: $private_flake_dir/flake.nix

            Create a sibling nix-vps-private flake there, or point
            NIX_VPS_PRIVATE_FLAKE at the real private flake location.

            The tracked template lives at:
              nix-vps/private-config-template
            EOF
              exit 1
            fi

            override_args=(--no-write-lock-file)
            if [ -n "''${NIX_VPS_NIX_SERVICES_FLAKE:-}" ]; then
              override_args+=(--override-input nix-services "path:$NIX_VPS_NIX_SERVICES_FLAKE")
            fi
            override_args+=(--override-input private "path:$private_flake_dir")

            private_source="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.privateConfig.source" --raw)"
            private_placeholder="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.privateConfig.isPlaceholder" --json)"

            if [ "$private_placeholder" = "true" ]; then
              echo "private config check failed: private flake source '$private_source' is still the placeholder template" >&2
              exit 1
            fi

            admin_user="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.adminUser" --raw)"
            domain="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.domain" --raw)"
            admin_keys_json="$(nix eval "''${override_args[@]}" "$flake_ref.config.lab.adminAuthorizedKeys" --json)"

            if ! printf '%s' "$admin_keys_json" | jq -e 'length > 0' >/dev/null; then
              echo "private config check failed: lab.adminAuthorizedKeys is empty for $node" >&2
              exit 1
            fi

            if [ "$quiet" -eq 0 ]; then
              echo "private config OK for $node"
              echo "private_source=$private_source"
              echo "admin_user=$admin_user"
              echo "domain=$domain"
              echo "admin_keys=$(printf '%s' "$admin_keys_json" | jq 'length')"
            fi
          '';
        };
        validateVpsHost = pkgs.writeShellApplication {
          name = "validate-vps-host";
          runtimeInputs = [ validatePrivateConfig pkgs.nix ];
          text = ''
            set -euo pipefail

            if [ "$#" -ne 1 ]; then
              echo "usage: validate-vps-host <nixosConfiguration>" >&2
              exit 1
            fi

            node="$1"
            validate-private-config --quiet "$node"
            repo_flake_path="path:${self}"
            private_flake_dir="''${NIX_VPS_PRIVATE_FLAKE:-$PWD/../nix-vps-private}"
            override_args=(--no-write-lock-file)
            if [ -n "''${NIX_VPS_NIX_SERVICES_FLAKE:-}" ]; then
              override_args+=(--override-input nix-services "path:$NIX_VPS_NIX_SERVICES_FLAKE")
            fi
            override_args+=(--override-input private "path:$private_flake_dir")
            flake_ref="$repo_flake_path#nixosConfigurations.$node"

            hostname="$(nix eval "''${override_args[@]}" "$flake_ref.config.networking.hostName" --raw)"
            toplevel_drv="$(nix eval "''${override_args[@]}" "$flake_ref.config.system.build.toplevel.drvPath" --raw)"

            echo "hostname=$hostname"
            echo "toplevel_drv=$toplevel_drv"
          '';
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.gitleaks
            pkgs.nodePackages.markdownlint-cli2
            pkgs.sops
            pkgs.age
            pkgs.zstd
            pkgs.nixos-rebuild
            pkgs.nixos-anywhere
            pkgs.deadnix
          ];

          shellHook = ''
            echo "Entering nix-vps dev shell"

            if [ -z "''${SKIP_PREK:-}" ] && [ -d .git ] && [ -f .pre-commit-config.yaml ] && command -v prek >/dev/null 2>&1; then
              if [ -z "''${NIX_VPS_PREK_DONE:-}" ]; then
                export NIX_VPS_PREK_DONE=1

                echo "prek: installing git hooks"
                prek install --install-hooks 2>/dev/null || prek install || true

                if [ -z "''${SKIP_PREK_RUN:-}" ]; then
                  echo "prek: running hooks (all files)"
                  prek run --all-files || true
                fi
              fi
            fi
          '';
        };

        packages.validate-private-config = validatePrivateConfig;
        packages.validate-vps-host = validateVpsHost;

        apps.validate-private-config = {
          type = "app";
          program = "${validatePrivateConfig}/bin/validate-private-config";
        };

        apps.validate-vps-host = {
          type = "app";
          program = "${validateVpsHost}/bin/validate-vps-host";
        };
      }
    );
}
