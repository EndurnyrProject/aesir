# AGENTS.md

This file provides guidelines for agentic coding agents operating in this repository.

## The Project

Aesir is a Ragnarok Online emulator written in Elixir. The objective is a stable, professional,
well-implemented server that follows good Elixir practices and is correct with respect to the
Ragnarok Online (Renewal) mechanics. The server talks to a custom Rust client over QUIC using a
Protobuf wire protocol (it is not the legacy kRO TCP/packet protocol).

## Project Structure

An Elixir umbrella (`apps/`) with four OTP applications:

1. **commons** - Shared functionality used by every server
   - Network layer (QUIC transport + Protobuf protocol)
   - Authentication (`Aesir.Commons.Auth`, bcrypt)
   - Database models and `Repo` (Ecto/Postgres)
   - Distributed session management (`SessionManager`, via Horde)
   - Inter-server communication (`inter_server/`, via Phoenix.PubSub)
   - Cluster setup (`cluster/`, via libcluster)

2. **account_server** - Authentication and login
   - Login request handling, account validation
   - Char-server list / selection, client version (`packetver`) checking
   - Hands the authenticated session to the char server

3. **char_server** - Character lifecycle
   - Character creation, listing, selection, deletion, slot management
   - Character data management
   - Hands off to a zone server on character select

4. **zone_server** - In-game world (by far the largest app)
   - Maps (walkability cache, per-map coordinators, pathfinding)
   - Units/entities (players, mobs, NPCs) and their state
   - MMO mechanics (combat, skills, status effects, jobs, items, leveling)
   - NPC scripting engine and dialog DSL
   - GM commands
   - Game content and the rAthena data-import pipeline

### Key Architectural Components

- **Umbrella Structure**: Each server is a separate OTP application within an umbrella project.
- **Distributed System**: libcluster for node discovery, Phoenix.PubSub for inter-server messaging.
- **Persistent Storage**: Ecto with Postgres (accounts, characters, inventory).
- **In-Memory / Cluster State**: Horde (distributed Registry) for sessions; ETS and `:persistent_term`
  for hot zone-server state (unit registry, map cache, status storage, NPC index, etc.).
- **Network Layer**: QUIC (`erlang_quic` via the `:quic` dep) with a Protobuf protocol (`:protox`).

## Network & Protocol

The wire protocol is a single Protobuf schema, not hand-rolled binary packets.
`apps/commons/proto/aesir.proto` is the single source of truth; `Aesir.Commons.Network.Proto`
generates the `Aesir.Net.*` structs from it, every frame carries exactly one `Aesir.Net.Envelope`,
and transport is QUIC (`QuicListener`/`QuicConnection`, framing in `QuinnetCodec`).

To add or change a message, load the **aesir-protocol** skill (Envelope numbering, routing
annotations, `mix aesir.gen.proto_routing`, `MessageRouter`, and when not to add a message).

## Session Management

The session system manages player connections and state across servers:

1. **Session Creation**: Started in the account server during login.
2. **Session Validation**: Used by char/zone servers to verify authentication.
3. **Distributed Storage**: Sessions are carried as Horde.Registry values (cluster-wide access);
   they are not persisted.
4. **Server Tracking**: Monitors which players are on which servers.
5. **Heartbeat System**: Detects disconnected nodes and cleans up orphaned sessions.

### Key Session Functions (`Aesir.Commons.SessionManager`)

- `create_session/2` - Creates a new session after successful login.
- `validate_session/3` - Validates session credentials when changing servers.
- `set_user_online/4` - Marks a user as online on a specific server (last two args optional).
- `end_session/1` - Cleans up session data when a user logs out.
- `register_server/6`, `update_server_heartbeat/2`, `get_servers/1` - Server registry/heartbeat.

Always verify the exact signature in the source before use; do not assume.

## Database Models

Persistent state is small and lives in `Aesir.Commons.Models`:

1. **Account** (`Aesir.Commons.Models.Account`) - Auth data (username, password hash), status, security.
2. **Character** (`Aesir.Commons.Models.Character`) - Stats, position/map, appearance, zeny, char vars,
   game state.
3. **InventoryItem** (`Aesir.Commons.Models.InventoryItem`) - Per-character inventory rows.

Most zone-server runtime state (live unit state, status effects, map cells, NPC placements) is held
in memory (ETS / `:persistent_term`) and only the durable bits are persisted back via
`CharacterPersistence` and the inventory persistence layer.

## Zone Server Subsystems

The zone server (`apps/zone_server/lib/aesir/zone_server/`) is where most work happens.
`MechanicsSupervisor` boots the subsystems in order (load map cache, status definitions, item
scripts, NPC registry/verifier, warps) and then starts the runtime supervisors.

- **`unit/`** - Polymorphic entity system. The `Unit` behaviour abstracts players/mobs/NPCs;
  `UnitRegistry` (ETS) keys live units by `{unit_type, unit_id}`; `SpatialIndex` does proximity
  queries; `Broadcast`/`SnapshotBuilder` push deltas to nearby players.
  - **`unit/player/`** - `PlayerSession` (GenServer) is the **single writer** for a player; all
    mutations route through it via cast/call handlers (movement, combat, skills, inventory, status,
    health, experience, stats, warp, script effects). `PlayerState` is an immutable snapshot.
  - **`unit/mob/`** - `MobSession` (GenServer, AI tick loop) per mob instance; `AIStateMachine` is a
    plain functional state machine (patrol/aggro/chase/attack/flee). Note: `gen_state_machine` is a
    listed dep but is **not** currently used.
- **`mmo/`** - Game mechanics. `combat/` (melee + magic damage, hit/crit, element/race/size mods),
  `skill/` + `skills/` (skill behaviour, catalog, cast/cooldown interpreter, ground units, and the
  individual skill modules), `status_effect/` (definition behaviour, interpreter, registry, ETS
  storage, tick manager, display metadata, and the individual effect modules), `job_management/`,
  `item_management/` (includes `ScriptCompiler` that compiles item scripts), `mob_management/`,
  plus `Leveling`, `StatPoint`, `SkillTree`, and generated `constants/` (`Efst`, `Opt1/2/3`,
  `Option`, `EffectId`).
- **`map/`** - `MapCache` (ETS walkability from `priv/maps.mcache`), `GatLoader`/`CacheLoader`
  (build the cache from `.gat`), `Coordinator` (per-map game loop: spatial index, spawns, snapshot
  broadcast), `MapManager` (lifecycle). `Pathfinding` (A*) and `Geometry` live at the app root.
- **`npc/` + `script/`** - The NPC system and scripting engine (see below).
- **`gm/`** - `Dispatcher` parses `@`-prefixed commands, gates on GM level, runs `Command` modules
  (e.g. `@item`, `@warp`).
- **`content/`** - Concrete game content, e.g. bespoke NPC modules under `content/npc/<map>/`.

## NPC System & Scripting DSL

NPCs are declarative Elixir modules under `content/npc/<map>/` with no compile-time coupling to
the engine: `Npc` (`use` macro with a `spawn:` placement list and an `on_talk/1` callback),
`Npc.Registry` (boot-time `:persistent_term` index composed with the `GameMode` overlay),
`Npc.Verifier`, `Npc.Warps` (from `priv/db/re/warps/*.yml`), and `Script.Dsl` / `Script.Ctx` /
`Script.Interaction` for dialog, effect, and read ops.

Load the **aesir-npc** skill before writing or porting any NPC, warp, or script buildin.

## Data & Content Pipeline

Game data is imported from rAthena into YAML/cache files under each app's `priv/`, then loaded at
boot. The mix tasks (in `apps/zone_server/lib/mix/tasks/`) are idempotent, deterministic importers:

- `mix aesir.gen.constants [<rathena_root>]` - Generates `mmo/constants/*.ex` from rAthena headers
  (`status.hpp`, `script.hpp`).
- `mix aesir.import.items [<rathena_root>]` - rAthena `item_db_*` -> `priv/db/re/items/*.yml`.
- `mix aesir.import.jobs [<rathena_root>]` - Merges rAthena job tables -> `priv/db/re/jobs/*.yml`.
- `mix aesir.import.mobs [<rathena_root>]` - rAthena `mob_db` -> `priv/db/re/mobs/mobs.yml`.
- `mix aesir.import.spawns [<rathena_root>]` - rAthena mob-spawn scripts -> `priv/db/re/spawns/<map>.yml`.
- `mix aesir.import.warps [<rathena_root>]` - rAthena warp scripts -> `priv/db/re/warps/<map>.yml`.
- `mix aesir.import.quests [<rathena_root>]` - rAthena `quest_db` -> `priv/db/re/quests/quests.yml`.
- `mix aesir.import.npcs [<rathena_root>] [--only <glob>] [--force]` - enabled shared, renewal,
  and pre-renewal NPC graphs -> one scoped module corpus.
- `mix aesir.import.mapcache [<gat_dir>] [<out>]` - `.gat` files -> `priv/maps.mcache` (zlib walkability).

Zone DBs use `:commons, :game_mode`: renewal is the default (`re/`), and
`AESIR_DB_MODE=pre_renewal` selects the shipped `pre-re/` corpus. Its pinned source,
complete regeneration sequence, and intentional exclusions are documented in
`apps/zone_server/priv/db/pre-re/README.md`. Local `priv/db/import/` YAML is gitignored and loads
after shipped data: keyed rows override, maps merge, and spawns append-only per map (base spawns
kept, import spawns added); warps and shops append. Restart after edits, or call the relevant
catalog's `reload/0`.

NPC import has its own rules (all-scope runs independent of `AESIR_DB_MODE`, `--only` semantics,
manifest ownership, `_conflicts/` and stale-output handling, helper resolution, and the pending
pre-renewal corpus regeneration). Read the transpiler section of the **aesir-npc** skill before
running `mix aesir.import.npcs`.

## Testing Approach

Tests follow standard Elixir patterns with some custom helpers:

1. **Unit Tests**: Test modules in isolation; use `Mimic` for mocking; follow AAA (Arrange, Act, Assert).
2. **Database Tests**: `Aesir.DataCase` provides transaction sandboxing and error-assertion helpers.
3. **Cluster Tests**: `Aesir.Commons.ClusterTestHelper` clears Horde registry entries between tests.
4. **ETS Tests**: `Aesir.TestEtsSetup` sets up ETS tables for tests.
5. **End-to-end**: Zone features (warps, NPC interactions, quests) have integration tests driving the
   real subsystems; mirror the existing ones when adding gameplay.

Mimic conventions, integration-test isolation, and known flaky tests are in the **aesir-workflow** skill.

## Build, Lint, and Test

- **Run all apps**: `mix aesir.all`
- **Run account server**: `mix aesir.account`
- **Run char server**: `mix aesir.char`
- **Run zone server**: `mix aesir.zone`
- **Format code**: `mix format`
- **Lint code**: `mix credo --strict`
- **Run all tests**: `mix test`
- **Run a single test file**: `mix test path/to/test_file.exs`
- **Run a single test**: `mix test path/to/test_file.exs:line_number`

Always run the full test suite before considering a task done.

## Tool Preferences

- For Elixir/Hex library documentation, prefer the docs MCP tooling over guessing from memory.

## Delegation

- Use `Explore`, `Scout`, or `codebase-memory-scout` for read-only lookups, and pass
  `model: "haiku"` for mechanical search or extraction work.
- Reserve `general-purpose` and the default model for work that writes, edits, or needs judgment.

## Code Style

- **Formatting**: Adhere to `.formatter.exs`. Run `mix format` before committing.
- **Linting**: Follow `.credo.exs`. Run `mix credo --strict`.
- **Naming**: `snake_case` for variables/functions, `CamelCase` for modules.
- **Error Handling**: Use `with` for complex paths and pattern-match on returns. Avoid exceptions for
  control flow; return `{:ok, result}` / `{:error, reason}`.
- **Typespecs**: Add `@spec` to all public functions.
- **Docs**: Add `@moduledoc`/`@doc` to public modules/functions and `@typedoc` to public types.
- **Prefer `with` over nested `case`**.
- **No superfluous comments**: Prefer module/function docs; comment inline only when genuinely needed.
- **Structs**: plain `defstruct` with an explicit `@enforce_keys` and a hand-written `@type t()`.
  Do not reach for a struct-generating macro library.
- **Aliases**: Always `alias` modules at the top of the file instead of using fully-qualified names.
- **Numbers**: Numbers larger than 9999 must use underscores, e.g. `10_000`.
- **Tell, don't ask**: Avoid `get`/`put` patterns; prefer passing state through function calls.
- **Reduce coupling**: Prefer `Phoenix.PubSub` to decouple subsystems when possible; broadcast events
  rather than calling another subsystem's modules directly, so producers and consumers stay independent.
- **Keep compile times low**: Avoid baking large/derived data into compile-time module attributes or
  generated functions — they recompile every dependent module on change. Prefer loading data at runtime
  and caching it in `:persistent_term` (with a `reload/0`), as in
  `Aesir.ZoneServer.Mmo.ItemManagement.Items` and `MobManagement.Mobs`.

## Development Guidelines

1. **Verify Everything**: Check function signatures, return values, and schema field names. Never
   assume a function or field exists.
2. **Protocol Changes**: New wire messages go through `apps/commons/proto/aesir.proto` and the
   generated `Aesir.Net.*` structs; do not hand-roll binary packets.
3. **Session Management**: Always validate sessions before processing user requests.
4. **Error Handling**: Use the `{:ok, result}` / `{:error, reason}` pattern instead of raising.
5. **Testing**: Write comprehensive tests for new functionality (happy path and error cases).
6. **Documentation**: Document modules and functions; for protocol messages document field meaning.
7. **Renewal Mechanics**: Ragnarok has pre-re and renewal mechanics; we target renewal.
8. **Never assume a function signature or return value**: Always check the definition.
9. **No distributed transactions between sessions**: Never build an offer/claim or two-phase-commit
   style protocol across PlayerSession/MobSession processes to coordinate a cross-unit effect (the
   Monk Root skill shipped one and it was deleted as unnecessary complexity). The single-writer rule
   covers a session's own state, but `StatusStorage` is deliberately not single-writer: writing
   another unit's status rows cross-process is the norm, and movement/attack gating is pull-based
   (`can_move?`/`can_attack?` checked per action/tick), so no session needs to be notified
   synchronously. When an effect must be granted exactly once, use a synchronous atomic claim on the
   shared store (`StatusStorage.take_status/3`) inside the acting process, then write both sides'
   records directly; let ticks and finite durations self-heal a dead peer.
