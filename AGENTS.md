# AGENTS.md

Working guide for agents operating inside `nix-vps/`.

## Purpose

`nix-vps` is the public host-ownership layer for VPS infrastructure. It owns:

- VPS NixOS flake outputs and host composition
- base host modules (`nixos/modules/`)
- host profile and disk layout (`nixos/profiles/`, `nixos/disko/`, `nixos/hosts/`)
- explicit private companion flake input (`../nix-vps-private`)
- host-side runtime secret provisioning (`sops-nix` to `/run/secrets`)
- host selection and wiring for services imported from `nix-services`
- host-owned public-safe records and operator guidance

`nix-vps` does not own shared service internals. Those belong in `../nix-services`.

## Start Here

When working in `nix-vps`, read in this order:

1. this file (`AGENTS.md`)
2. `records/SESSION_PROMPT.md`
3. `flake.nix`
4. relevant files under:
   - `nixos/modules/`
   - `nixos/profiles/`
   - `nixos/hosts/`
   - `nixos/disko/`
5. paired private config in `../nix-vps-private/modules/`
6. relevant private investigation notes in `../nix-vps-private/records/<service>/INVESTIGATION.md`

If a task touches shared module behavior, follow pointers to `nix-services` instead of duplicating logic in this repo.

## Ownership Boundary

Use `nix-vps` for:

- VPS host lifecycle and rebuild workflows
- users, SSH, networking, Docker enablement, hardening
- SOPS host bootstrap wiring and secret consumption contracts
- host-specific service enablement/wiring
- host-specific runtime divergence from shared service modules
- public-safe records and handoff documentation

Use `nix-services` for:

- shared service module behavior
- service options/contracts
- compose/systemd generation patterns
- service READMEs and service-level runbooks

Rule: if the change is reusable service behavior, it likely belongs in `nix-services`, not `nix-vps`.

## Repo Structure

- `flake.nix`: flake inputs/outputs, host definitions, validation apps, dev shell
- `nixos/modules/`: common VPS host primitives
- `nixos/profiles/`: VPS profile(s)
- `nixos/hosts/`: host entry modules
- `nixos/disko/`: disk layout declarations
- `private-config-template/`: tracked placeholder private flake and module
- `records/`: public-safe continuity docs
- `../nix-vps-private/modules/`: canonical private host values
- `../nix-vps-private/secrets/`: SOPS-encrypted private secrets
- `../nix-vps-private/records/`: private continuity/investigation notes

## Important Working Rules

- Treat `../nix-vps-private` as the canonical private source of truth.
- Before build/rebuild, run:
  - `nix run "path:$PWD#validate-private-config" -- vps-01`
- For direct `nix build` and `nixos-rebuild` commands, pass:
  - `--override-input private "path:${NIX_VPS_PRIVATE_FLAKE:-$PWD/../nix-vps-private}"`
- Never commit plaintext secrets.
- Decrypted secrets must only appear at runtime under `/run/secrets`.
- `lab.sops.ageKeyFile` must point to a host file, never a Nix store path.
- Prefer the repo-local `nix develop` shell for hooks and tooling.
- If you will commit or push, do that work from inside `nix develop` so the
  expected hook binaries are available.
- Do not use `--no-verify` to work around missing local tools; enter
  `nix develop` and rerun the normal workflow instead.
- Start each session with:
  1. `git fetch origin`
  2. `git pull --rebase origin main`
  3. `git status --short --branch`
- End finished tasks by committing and pushing to `origin` unless explicitly told not to.
- If a change affects running behavior, the task is only complete after rollout and live verification.

## Secrets And Private Data

- Committed secret material must stay SOPS-encrypted under `../nix-vps-private/secrets/`.
- Host age private keys stay outside Git (typically `/var/lib/sops/age.key`).
- Private continuity notes, real hostnames/IPs, and operator-specific workflow belong in `../nix-vps-private/records/`, not this public repo.

## Build, Deploy, And Validation Norms

- Validate private wiring before evaluation/build:
  - `nix run "path:$PWD#validate-private-config" -- vps-01`
- Typical deploy flow (from `nix-vps/`):
  - `nixos-rebuild switch --no-reexec --flake .#vps-01 --override-input private "path:../nix-vps-private" --target-host <user>@<host> --sudo`
- Keep `records/SESSION_PROMPT.md` current when workflow or known-good commands change.

## Investigation Files

Each service area can have an investigation file under:

- `../nix-vps-private/records/<service>/INVESTIGATION.md`

Convention:

- Before working on a service, read its investigation file if present.
- If none exists, create one before the session ends.
- After discovering new facts or fixing issues, update it.

Investigation files belong in the private companion because they commonly include sensitive operational details.

## Session Continuity

If work is part of ongoing operations, check:

- `records/SESSION_PROMPT.md` (public summary)
- `../nix-vps-private/records/SESSION_PROMPT.md` (private operational state)
- `../nix-vps-private/records/<service>/INVESTIGATION.md` (service deep dives)

Prefer appending/refreshing records over deleting history.

## Practical Decision Heuristics

- Change reusable service module behavior:
  work in `nix-services`.
- Enable or wire existing shared services on VPS host:
  work in `nix-vps` + `nix-vps-private`.
- Add/rotate secrets:
  update SOPS-encrypted data in `nix-vps-private` and reference `/run/secrets/...`.
- Change host-only hardening/network/user policy:
  work in `nix-vps/nixos/modules/`.

## Avoid

- duplicating shared service logic from `nix-services`
- committing plaintext secrets or private identifiers
- building/deploying without overriding the private flake input
- treating `nix-vps-private` as optional placeholder data
