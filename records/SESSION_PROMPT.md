# Session Prompt

Next session continuation for nix-vps work.

## Current State (as of 2026-04-03)

All core infrastructure is deployed and working on the OVH VPS.

| Service | Status |
|---|---|
| NixOS 25.05 | running |
| Traefik (traefikCompose) | active |
| MySQL | active |
| Ghost (`primary.example`) | active |
| WireGuard hub | active — pi-node-a (10.0.0.2) and pi-node-b (10.0.0.3) connected |
| CrowdSec + firewall bouncer | active |
| node-exporter, cAdvisor, Promtail | active, scraped by a Prometheus peer |

### Security hardening status (2026-04-03)

- SSH remains key-only (no local password login workflow).
- SSH daemon policy tightened in `nixos/modules/ssh.nix`:
  - `AuthenticationMethods = publickey`
  - `KbdInteractiveAuthentication = false`
  - `AllowAgentForwarding = no`
  - `X11Forwarding = false`
  - `AllowUsers = [ <admin user> ]`
  - `UseDns = false`
  - lower auth attack surface (`LoginGraceTime`, `MaxAuthTries`, `MaxSessions`, `MaxStartups`)
- Docker firewall trust narrowed:
  - removed broad trusted Docker interfaces in private host config
  - replaced with explicit iptables INPUT allow rule for TCP/3000 from Docker bridge CIDR `172.16.0.0/12`
  - this preserves Traefik -> Umami connectivity while reducing bridge-to-host trust
- Changes were deployed to `vps-host` and verified live:
  - `sshd -T` shows hardened values (`authenticationmethods publickey`, `allowagentforwarding no`, etc.)
  - Traefik -> Umami heartbeat is healthy internally and externally

## VPS Facts

| Item | Value |
|---|---|
| IP | 203.0.113.10 |
| SSH user | `<admin-user>` |
| SSH key | `/home/<admin-user>/.ssh/id_ed25519_homelab` |
| Hostname | `vps-host` |
| OS | NixOS 25.05 |
| Disk | 40G on `/dev/sda` (BIOS/GRUB boot) |
| RAM | 1.9G |
| CPU | 2 cores |
| Swap | 2G |
| Provider | OVH IE |

Connect: `ssh -i ~/.ssh/id_ed25519_homelab <admin-user>@203.0.113.10`

## Repo Layout

| Repo | Path | Remote |
|---|---|---|
| Public config | `hhlab-insfrastructure/nix-vps/` | `ssh://git@gitea.internal.example:2222/<git-user>/nix-vps.git` |
| Private config | `hhlab-insfrastructure/nix-vps-private/` | `ssh://git@gitea.internal.example:2222/<git-user>/nix-vps-private.git` |
| nix-services | `hhlab-insfrastructure/nix-services/` | `ssh://git@gitea.internal.example:2222/<git-user>/nix-services.git` |

## How to Deploy Changes

```bash
cd nix-vps
nixos-rebuild switch \
  --no-reexec \
  --flake ".#vps-host" \
  --override-input private "path:../nix-vps-private" \
  --target-host <admin-user>@203.0.113.10 \
  --sudo
```

**Important**: use `--no-reexec`. Without it, nixos-rebuild re-executes itself using
the flake's pinned nixpkgs nixos-rebuild binary, which is older and does not support
`--sudo`. `--no-reexec` keeps the local system's nixos-rebuild throughout.

## Architecture Notes

- **BIOS/GRUB not UEFI**: OVH VPS boots in legacy BIOS mode. Do not set `boot.loader.grub.device` explicitly.
- **Docker data root**: `/srv/docker`
- **Compose root**: `/srv/compose`
- **Private flake override**: All nix commands need `--override-input private "path:../nix-vps-private"` since the public flake points at a placeholder template.
- **Traefik renamed**: `services.traefik` → `services.traefikCompose` (avoids conflict with NixOS 25.05 built-in Traefik module). Requires explicit `services.traefikCompose.enable = true`.
- **WireGuard topology**: VPS is hub at `10.0.0.1/24`. Pis connect as spokes. Keys in SOPS secrets.
- **CrowdSec metrics**: exposed on WireGuard interface `10.0.0.1:6060`, scraped by a Prometheus peer.

## Domain and DNS

- **Primary domain**: `primary.example` — registered on Namecheap, DNS on Cloudflare
- **A record**: `primary.example → 203.0.113.10`

### Email DNS (Zoho Mail — do not touch)

| Record | Value |
|---|---|
| MX | `mx.zoho.eu` (10), `mx2.zoho.eu` (20), `mx3.zoho.eu` (50) |
| SPF | `v=spf1 include:zohomail.eu ~all` |
| DKIM | `zoho._domainkey.primary.example` |
| DMARC | `v=DMARC1; p=none; rua=mailto:admin@secondary.example` |

## SOPS Secrets

- Age key on VPS: `/var/lib/sops/age.key`
- VPS public key: `age1examplevpspublickeyxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- Dev machine public key: `age1exampledevpublickeyxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
- Secrets file: `nix-vps/secrets/secrets.yaml`
- Contains: `mysql_root_password`, `mysql_ghost_password`, `cloudflare_api_token`

## What Comes Next

### 1. Decide on Docker socket proxy exposure (`wg0:2375`)

Keep only if actively required by trusted WireGuard peers; otherwise remove from
`networking.firewall.interfaces.wg0.allowedTCPPorts`.

### 2. Add periodic security drift checks

- new public listeners
- cert renewal failures
- unexpected container restarts/image drift

### 3. secondary.example

Static page or simple site. Domain registered on Namecheap. DNS likely also on
Cloudflare. Discuss approach (static HTML, Ghost second instance, redirect)
before implementing.
