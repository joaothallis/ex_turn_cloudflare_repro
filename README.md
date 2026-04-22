# ex_turn_cloudflare_repro

Minimal reproduction of STUN 437 "Allocation Mismatch" from
[ExTURN.Client](https://hex.pm/packages/ex_turn) v0.2.1 against Cloudflare
TURN.

## What this proves

`ExTURN.Client` v0.2.1 exposes no `close/1` and never sends
`Refresh(lifetime=0)` when a PeerConnection stops. On Cloudflare, allocations
outlive the local UDP socket. When a later PeerConnection binds a 5-tuple
that collides with a still-live allocation, Cloudflare rejects Allocate with
STUN error **437**, and no `typ relay` ICE candidate is emitted.

This script forces the collision deterministically by pinning
`ice_port_range` to a narrow window (5 ports by default) and opening/closing
`PeerConnection`s back-to-back with no cooldown.

## How to run

### Cloudflare (should go RED — exit code 2)

```bash
export CF_TURN_APP_ID=...
export CF_TURN_APP_TOKEN=...
mix deps.get
mix run -e "ExTurnCloudflareRepro.run()"
```

Expected log output includes at least one:

```
[warning] Failed to create allocation, reason: 437. Closing client.
```

and the process exits with status `2`.

### coturn control (should go GREEN — exit code 0)

```bash
docker compose up -d coturn
TURN_SERVER=coturn mix run -e "ExTurnCloudflareRepro.run()"
```

All iterations emit `typ relay`, no 437, exit status `0`. This isolates the
failure to Cloudflare-specific allocation lifecycle vs. a generic TURN
server.

## Interpreting the signal

| Exit | Meaning |
| ---- | ------- |
| `0`  | GREEN — no 437 in N iterations. Either the fix has landed, the port range is too wide, or the target TURN server collects allocations promptly. |
| `2`  | RED — the bug reproduces. |

When running against a forked `ex_turn` that sends `Refresh(lifetime=0)` on
close, the Cloudflare run should flip from RED to GREEN without any other
change.

## Tunables (env vars)

| Var | Default | Purpose |
| --- | ------- | ------- |
| `TURN_SERVER` | `cloudflare` | `cloudflare` or `coturn` |
| `REPRO_ITERATIONS` | `20` | Number of PC open/close cycles |
| `REPRO_PORT_RANGE_START` | `50000` | First UDP source port |
| `REPRO_PORT_RANGE_SIZE` | `5` | Number of contiguous source ports |
| `CF_TURN_APP_ID` / `CF_TURN_APP_TOKEN` | — | Required when `TURN_SERVER=cloudflare` |
| `COTURN_URL` / `COTURN_USERNAME` / `COTURN_CREDENTIAL` | `turn:127.0.0.1:3478?transport=udp` / `repro` / `repro` | Only when `TURN_SERVER=coturn` |

## Dependencies (pinned)

```elixir
{:ex_webrtc, "~> 0.14.0"},
{:ex_ice, "== 0.14.0", override: true},
{:ex_turn, "~> 0.2.1"},
{:req, "~> 0.5"}
```

## References

- RFC 5766 §6.2 — 437 Allocation Mismatch
- RFC 5766 §7.2 — Refresh messages
- Reference implementations that *do* send `Refresh(lifetime=0)`:
  - libwebrtc `p2p/base/turn_port.cc` `TurnPort::Release()`
  - Pion `pion/turn internal/client/udp_conn.go:259-274`
  - aiortc `aioice src/aioice/turn.py:166-185`
