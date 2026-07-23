---
name: aesir-protocol
description: How to add or change wire messages in Aesir - the single Protobuf schema, Envelope numbering, zone-server MessageRouter routing, and when NOT to add a message. Use when a feature needs new client-server communication.
---

# Wire protocol changes in Aesir

The protocol is one Protobuf schema over QUIC — never hand-rolled binary packets, and not
the legacy kRO packet protocol.

## First question: do you actually need a new message?

A new message is a **cross-repo contract**: the Rust client (lifthrasir) must implement it
too, so a server-only feature that adds a message ships unplayable until the client catches
up. Exhaust the existing routes first:

- Player-visible state changes: existing authoritative messages (`UnitStateChange`, status
  icon packets, snapshot deltas).
- NPC/script output: the Script DSL primitives (`mes`/`select`/`npctalk`/...).
- Skill menus: the skill-staged dialog pattern (`PlayerState.pending_interaction` +
  `Script.Interaction` with synthetic gid `0x6000_0000`) instead of a bespoke menu message.

When a menu-like need recurs, prefer one generic message pair over per-feature ones.

## Adding a message

1. Edit `apps/commons/proto/aesir.proto`: add the `message`, then add it to the `Envelope`
   `oneof body` with a free field number in the right range — **16-31 control, 32-63 client
   intents, 64+ authoritative/world**. (Recent world messages: Viewpoint 134, Cutin 135,
   SoundEffect 136.)
2. Recompile commons — `Aesir.Commons.Network.Proto` (`use Protox`) regenerates the
   `Aesir.Net.*` structs; the `.proto` is an `@external_resource` so edits force recompile.
3. Route it:
   - **Zone server, client→server**: add a `route/1` clause in
     `apps/zone_server/lib/aesir/zone_server/network/message_router.ex` mapping the struct
     to a `{domain, tag}` (`{:control, ...}`, `{:gameplay, ...}`, `{:world, ...}`), then
     handle that tag in the player-session packet routing/handlers. Sessions have **no
     catch-all `handle_info`** — a missed sender after a rename is a FunctionClauseError and
     a player disconnect; renames must be atomic with grep-verified sender sweeps.
   - **Account/char servers**: handle the new `{tag, msg}` body in that server's
     `handle_message/3` (the `Aesir.Commons.Network.QuicConnection` behaviour callback).
   - **Server→client**: build the `Aesir.Net.*` struct and send via the broadcast layer
     (`Broadcast.to_player` for SELF-targeted, area broadcast otherwise). No-op gracefully
     when `char_id` is nil (detached script contexts).
4. Document field meanings on the proto message.
5. Coordinate the Rust client: prost regenerates from the same schema; client-side handling
   is a separate change in lifthrasir. Note which packet is load-bearing for the client
   (e.g. it derives cart/mount state purely from `UnitStateChange` effect bits).

## Encoding reference

```elixir
alias Aesir.Net.{Envelope, LoginRequest}

{:ok, iodata, _size} =
  %Envelope{seq: 1, body: {:login_request, %LoginRequest{username: "u", password: "p"}}}
  |> Envelope.encode()

{:ok, %Envelope{body: {tag, msg}}} = Envelope.decode(binary)
```

`seq` is a per-sender monotonic counter for correlation. Framing is handled by
`QuinnetCodec`; transport by `QuicListener`/`QuicConnection` — you should not need to touch
either for a normal message addition.
