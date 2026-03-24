{ config, lib, ... }:
let
  repoRoot = ../..;
  defaultSopsFilePath = repoRoot + "/secrets/secrets.yaml";
  inferredDefaultSopsFile =
    if builtins.pathExists defaultSopsFilePath
    then builtins.path { path = defaultSopsFilePath; name = "secrets.yaml"; }
    else null;

  effectiveDefaultSopsFile =
    if config.lab.sops.defaultSopsFile != null
    then config.lab.sops.defaultSopsFile
    else inferredDefaultSopsFile;

  effectiveDefaultSopsFileStorePath =
    if effectiveDefaultSopsFile != null
    then builtins.path { path = effectiveDefaultSopsFile; name = "secrets.yaml"; }
    else null;
in
{
  config = lib.mkMerge [
    {
      assertions = [
        {
          assertion = !(lib.hasPrefix "/nix/store/" config.lab.sops.ageKeyFile);
          message = "lab.sops.ageKeyFile must point to a host file, not a Nix store path.";
        }
      ];

      sops = {
        age.keyFile = config.lab.sops.ageKeyFile;
      };
    }

    (lib.mkIf (effectiveDefaultSopsFileStorePath != null) {
      sops.defaultSopsFile = effectiveDefaultSopsFileStorePath;

      system.extraDependencies = [ effectiveDefaultSopsFileStorePath ];
    })
  ];
}
