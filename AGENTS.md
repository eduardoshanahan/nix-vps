# AGENTS.md

This file is the working guide for agents operating inside `nix-pi/`.

`nix-pi` is the host-ownership layer of the homelab. It owns:

- Raspberry Pi NixOS flake outputs and SD-image workflows
- base host modules (`nixos/modules/`)
- explicit private companion flake input (`../nix-pi-private`)
- host-side runtime secret provisioning (`sops-nix` to `/run/secrets`)
- host selection and wiring for services imported from `nix-services`
- host-owned operational docs, divergence registers, and runbooks

`nix-pi` does not own shared service internals. Those belong in `../nix-services`.

## Start Here

When working in `nix-pi`, read in this order:

1. `README.md`
2. `DOCUMENTATION_INDEX.md`
3. `docs/README.md`
4. the specific operator/policy doc for the task:
   - `docs/lifecycle/SETUP.md`
   - `docs/lifecycle/PROVISIONING.md`
   - `docs/lifecycle/SECRETS.md`
   - `docs/lifecycle/REMOTE_BUILDS.md`
   - `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
   - `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
   - `../nix-pi-private/docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md`
5. the relevant implementation files in:
   - `flake.nix`
   - `nixos/modules/`
   - `nixos/profiles/`
   - `nixos/hosts/`
   - `../nix-pi-private/modules/`
6. `records/README.md` plus the relevant records files if session continuity matters

If a pointer doc exists here and points to `nix-services`, follow the pointer instead of duplicating policy locally.

## Ownership Boundary

Use `nix-pi` for:

- host lifecycle
- image builds and flashing workflows
- users, SSH, networking, Docker enablement
- SOPS and host bootstrap material
- host-specific service enablement and wiring
- host-specific runtime divergence from shared service modules
- host-owned monitoring inventory and operator docs

Use `nix-services` for:

- shared service module behavior
- service options/contracts
- generated compose/systemd patterns
- service READMEs and service-side runbooks

Rule: if the change is a reusable service behavior change, it probably belongs in `nix-services`, not here.

## Repo Structure

- `flake.nix`: flake inputs, NixOS outputs, dev shell
- `nixos/modules/`: common host primitives
- `nixos/profiles/`: RPi image profiles
- `nixos/hosts/`: public host entry modules
- `scripts/`: operational helper scripts
- `docs/`: canonical public-safe host-owned docs
- `DOCUMENTATION_INDEX.md`: quick navigation index for repo-level docs
- `records/`: long-lived public-safe project/session records
- `../nix-pi-private/docs/`: private operator notes and continuity files
- `secrets/`: SOPS-encrypted secret files safe to commit
- `../nix-pi-private/docs/local/`: private local runbooks and execution notes
- `../nix-pi-private/prompts/`: private prompts and session helpers

## Important Working Rules

- Treat the sibling private flake as the canonical private source of truth.
- Use `nix run "path:$PWD#validate-private-config" -- <host>` before builds or rebuilds.
- For direct `nix build` and `nixos-rebuild` commands, pass `--override-input private "path:${NIX_PI_PRIVATE_FLAKE:-$PWD/../nix-pi-private}"`.
- Never put plaintext secrets in Git.
- Decrypted secrets must only appear at runtime under `/run/secrets`.
- `lab.sops.ageKeyFile` must point to a host file, never a Nix store path.
- Prefer the repo-local `nix develop` shell for commits, hooks, and tool-driven work.
- At the start of a session, enter `nix develop`, run `git fetch origin`, then
  `git pull --rebase origin main`, and check `git status --short --branch`
  before editing.
- Do not bypass hooks by default. Missing tools usually means the shell is wrong, not that hooks should be skipped.
- At the end of a finished task, commit and push the resulting branch state to
  `origin` unless the user explicitly asks to leave work local.
- If the task changes service behavior, finish the rollout after push with a
  full rebuild of the owning host and verify on the live system that the fix
  still works after that rebuild.
- Keep the public repo anonymized unless the user explicitly wants a de-anonymizing change.
- Treat `records/` as part of the operating model, not disposable notes.

## Secrets And Private Data

- Committed secret material must stay SOPS-encrypted under `secrets/`.
- Host age private keys live outside Git, normally at `/var/lib/sops/age.key`.
- Builder signing keys are separate from SOPS and also stay outside Git.
- Private/environment-specific values belong in the sibling private companion
  repo, not public docs.
- Real private values now live in `../nix-pi-private`. Do not echo them into new files, docs, or commit messages.
- Private continuity notes, real host identifiers, real internal IPs, and
  operator-specific workflow belong in `../nix-pi-private/docs/`, not in the
  public repo.

## Build, Deploy, And Validation Norms

- Generic SD image outputs are defined for `rpi4`, `rpi3`, and optional `rpi3-armv7l`.
- Host outputs exist for `pi-node-a`, `pi-node-b`, and `pi-node-c`.
- `pi-node-c` is normally rebuilt with `pi-node-b` as its remote builder and signer.
- If a task touches remote builds, signing, or trust, also update `docs/lifecycle/REMOTE_BUILDS.md`.
- If a task changes host provisioning or bootstrap expectations, also update `docs/lifecycle/PROVISIONING.md` and/or `docs/lifecycle/SECRETS.md`.

## Host-Specific Reality

### `pi-node-a`

- Pi-hole primary
- Traefik, Promtail, cAdvisor, Tailscale, Docker socket proxy
- static LAN addressing and internal DNS preference

### `pi-node-b`

- main app and monitoring hub
- USB-backed `/srv` storage is the intended home for persistent state
- NFS media mount at `/mnt/media`
- large host-specific config surface in `../nix-pi-private/modules/pi-node-b.nix`
- host-managed Uptime Kuma monitor inventory
- intentional Homepage Docker inventory override
- intentional Ghost compose override for SMTP TLS behavior

### `pi-node-c`

- Loki host
- trusts `pi-node-b` Nix signing key for remote builds

## Documentation Sync Rules

When you change behavior, update the owning docs in the same change.

Especially:

- host runtime divergence changes:
  update `docs/policy/HOST_RUNTIME_DIVERGENCES.md`
- Uptime Kuma host-managed monitor changes:
  update `docs/policy/UPTIME_KUMA_MONITOR_POLICY.md`
- provisioning/bootstrap changes:
  update `docs/lifecycle/PROVISIONING.md`, `docs/lifecycle/SECRETS.md`, or `docs/lifecycle/REMOTE_BUILDS.md`
- storage-policy changes on `pi-node-b`:
  keep `README.md` and `docs/operations/OPERATIONS_CHECKS_AND_SERVICE_NOTES.md` aligned

If a local doc is pointer-only, update the canonical file in `nix-services` instead.

## `pi-node-b.nix` Guidance

`../nix-pi-private/modules/pi-node-b.nix` is large and mixes:

- host imports from `nix-services`
- SOPS secret declarations
- service enablement and host wiring
- monitoring target inventories
- Homepage dashboard config
- host-specific overrides and systemd units

When editing it:

- make the smallest scoped change possible
- search for related inventory/config in the same file before adding new values
- check whether a behavior is host-specific or should move into `nix-services`
- preserve existing patterns for optional modules guarded by `has...Module`

## Scripts

Use the existing helper scripts instead of rewriting ad hoc commands when possible:

- `scripts/export-sd-image`
- `scripts/inject-ssh-key`
- `scripts/bootstrap-sops-age-key`
- `scripts/bootstrap-nix-signing-key`

If you change a script’s contract, update the relevant docs in the same change.

## Session Continuity

If the task is part of ongoing operational/project work, check:

- `records/DECISIONS.md`
- `records/WORKLOG.md`
- `records/SESSION_PROMPT.md`
- `records/QUESTIONS.md`
- `records/RISKS.md`

Prefer appending new record entries over rewriting historical ones.

## Practical Decision Heuristics

- Need to change a shared module option or compose generation pattern:
  work in `nix-services`.
- Need to enable or wire an existing shared service on one host:
  work in `nix-pi`.
- Need to capture a one-host exception from shared behavior:
  implement in `nix-pi` and document it in `docs/policy/HOST_RUNTIME_DIVERGENCES.md`.
- Need to add a secret:
  add SOPS-encrypted source data plus host declaration pointing to `/run/secrets/...`.
- Need to use private values:
  prefer `../nix-pi-private` plus the explicit private flake override flow.

## Avoid

- duplicating shared service logic from `nix-services`
- committing plaintext secrets or private identifiers unnecessarily
- assuming `nix build .#...` will automatically pick up the private companion flake
- editing host runtime behavior without updating the owning docs
- treating `../nix-pi-private` as a throwaway example
