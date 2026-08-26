---
name: aesir-npc
description: How to create NPCs in Aesir - the declarative Npc module + Script DSL, dialog/effect/read ops, On-events (touch/timer/mob-death), script variables, and the rAthena NPC transpiler workflow (mix aesir.import.npcs, CommandMap, manifest). Use when writing or porting NPCs, warps, or NPC script buildins.
---

# Creating NPCs in Aesir

## Hand-written NPCs

NPCs are declarative Elixir modules under
`apps/zone_server/lib/aesir/zone_server/content/npc/<map>/<name>.ex` with no compile-time
engine coupling. A body defaults to `:shared`; restrict it explicitly when its behavior belongs to
one mode:

```elixir
use Aesir.ZoneServer.Npc,
  scope: :renewal,
  spawn: [%{map: "morocc", x: 208, y: 90, dir: 6, sprite: 58, name: "Renewal Guide"}]
```

A placement inherits its body scope, but a shared body may independently declare overlay placements:

```elixir
use Aesir.ZoneServer.Npc,
  spawn: [
    %{map: "prontera", x: 10, y: 10, sprite: 58, name: "Guide"},
    %{map: "izlude", x: 20, y: 20, sprite: 58, name: "Guide", scope: :renewal}
  ]
```

A placement cannot activate an inactive body. `scope:` accepts only `:shared`, `:renewal`, or
`:pre_renewal`.

- `spawn:` placements require `%{map, x, y, sprite}`; `dir` defaults to `0` and `name` to `""`.
  They also accept optional `unique_name` (rAthena exname, used for `donpcevent "Name::Label"`
  resolution) and `trigger: {xs, ys}` (OnTouch rect half-extents).
- Callbacks: `on_talk/1` (required), `on_init/1` and `on_event/2` (optional). `events/0` is
  auto-derived from `on_event/2` **literal** clause heads (non-literal head = CompileError).
- `Npc.Registry` (`:persistent_term`) composes shared content with the boot-selected `GameMode`
  overlay before it builds placement, cell, gid, name, label, touch, or event indexes. It assigns
  deterministic synthetic gids from `{map, x, y, unique_name}`. `Npc.Verifier` reports active
  same-cell/same-name collisions without blocking boot.
- Warp portals are data, not modules: `apps/zone_server/priv/db/<mode>/warps/*.yml`
  (mode dir `re/` or `pre-re/` per `AESIR_DB_MODE`; see `aesir-game-modes`).

## The Script DSL (`script/dsl.ex`)

All ops thread a `Script.Ctx` (fields: `char_id`, `account_id`, `game_state`, `source`,
`npc_gid`, `session_pid`, `vars`, ...). Three families:

- **Blocking dialog primitives** — `mes/2`, `next/1`, `select/2`, `input/3`, `close/1`.
  These suspend the `Script.Interaction` Task (a supervised coroutine) on a `receive` until
  the client responds. `close/1` terminates by `throw({:script_end, ctx})`.
- **Effect ops** `(ctx, args) -> ctx` — `heal`, `sc_start`, `sc_end`, `warp`, `give_item`,
  `delitem`, `pay_zeny`, `set_char_var`, `jobchange`, `savepoint`, `summon_mob`, `npctalk`,
  `emotion`, `specialeffect`, `cutin`, timer ops, `enablenpc`/`disablenpc`, ... Player-state
  mutations route to the PlayerSession via the `{:script_apply, op}` seam (handled in
  `ScriptEffectHandler`).
- **Read ops** `(ctx) -> value` — `zeny`, `count_item`, `get_char_var`, `base_level`,
  `class`, `char_name`, `job_name`, `can_change_job?`, `getskilllv`, ...

Script variables (`Script.Vars`): `$` server-permanent (Postgres `server_variables`),
`$@` server-temp (ETS), `#`/`##` account (Postgres `account_variables`, sigil kept in the
key), `.` NPC-scoped (ETS keyed `{ctx.source, name}` — shared across placements of a
script), `@`/plain char vars via the session. String vars keep the trailing `$` in the key.
External-store vars are read/written directly by the interaction Task, not via
`{:script_apply}`.

## On-events

- `Npc.Events` is the only dispatch seam: `trigger` (donpcevent, detached), `trigger_all`,
  `trigger_gid`, `trigger_attached`, `run_on_init` (boot). Detached ctx has
  `game_state: nil` — player effects halt `{:error, :no_player}`, player reads raise.
- `Npc.Session` (per-gid, on-demand GenServer) owns rAthena timers and enabled/hidden flags
  (mirrored to the `:npc_session_flags` ETS table; missing row = visible).
- OnTouch: rect scan in `MovementHandler` (warp check wins); busy players skip-but-mark.
- OnMyMobDead: `summon_mob event:` stamps `MobState.owner_event`; the map Coordinator's
  death path dispatches to the killer.
- `ClockScheduler` (OnClock events) is disabled in `Mix.env() == :test`.

## The rAthena transpiler

`mix aesir.import.npcs [<rathena_root>] [--only <glob>] [--force]` transpiles upstream
`npc/**/*.txt` into DSL modules. Run it from the repository root. With no `--only`, it follows
the enabled shared, renewal, and pre-renewal configuration graphs rooted at
`npc/re/scripts_main.conf` and `npc/pre-re/scripts_main.conf`, deduplicates shared files, and
emits one all-scope corpus. This import is independent of `AESIR_DB_MODE`. `--only` globs are
relative to `npc/` (for example `re/jobs/1-1/*`); they are targeted, incremental, and
non-authoritative, so they may select disabled files but never prune unrelated manifest records or
outputs.

Placed-script output continues to mirror the source path. Scoped floating scripts and global helpers
use separate namespaces: shared `Content.Npc.{Floating,Functions}` under `content/npc/{floating,functions}`;
renewal `Content.Npc.Re.{Floating,Functions}` under `content/npc/re/{floating,functions}`; and
pre-renewal `Content.Npc.PreRe.{Floating,Functions}` under
`content/npc/pre_re/{floating,functions}`. A scope-independent target is a direct call. A shared
caller to one or more overlay targets emits `GameMode` branches even for one target and raises in a
missing active mode. A known incompatible scope blocks import; a globally unknown helper remains a
`Todo` stub.

Pipeline lives under `npc/transpiler/`; state in `priv/npc_transpile/manifest.json`; stub report at
`priv/npc_transpile/_transpile_report.md`.

Rules that repeatedly bite:

- A no-argument run is authoritative for its enabled graphs. After structural validation, it deletes
  only untouched, manifest-owned stale outputs and their records; it removes records for already
  missing stale outputs. An edited stale output is retained, reported, and fails the run. `--only`
  never performs that reconciliation. Stale removal is post-write and non-transactional: active
  writes and successful removals persist; a failed removal and its manifest record remain retryable.
- Manifest paths cannot escape the app root or traverse symlinks. A hand-written output collision is
  reported and diverted to `_conflicts/`, while unrelated processing may continue; a multiply-owned
  manifest path blocks the import.
- `--force` regenerates matching entries even when their source is unchanged (use after
  transpiler/codegen changes); hand-edited outputs still divert to `_conflicts/`.
- Generated and hand-written files share `content/npc`; this stack did not migrate the checked
  corpus or manifest. Before any pre-renewal boot or deployment, remove only `output_path` files
  listed in the current manifest, preserving every other file; remove the manifest; then run one
  clean no-`--only` all-scope regeneration. Do not delete the directory. The user owns that
  regeneration after this stack.
- Unsupported buildins become runtime-raising `todo(ctx, :name, args)` stubs. Implementing
  one = add a DSL op + a `CommandMap` entry (or `@call_reads`/`@functions` for reads and
  global callfuncs), then force-regen. Codegen-native reads must also be added to Analyzer
  `@native_cmds` — keep the two in sync. Buildin lookups are case-insensitive; `read/1`
  params and `function/1` names are case-sensitive.
- Global upstream functions map onto DSL primitives via `CommandMap.function/1`
  (`Job_Change` → `jobchange` is the template).

## Testing

Mirror the existing end-to-end tests (`test/integration/npc_events_integration_test.exs`,
quest/warp integration tests). Sharp edge: `IntegrationCase.setup_ets_tables/1` shares the
boot-time UnitRegistry/SpatialIndex with the live prontera Coordinator — movement/warp
scenarios must isolate via `Aesir.TestEtsSetup.setup_ets_tables/1`. Var tests need
`DataCase` + `setup_ets_tables` (`dsl_vars_test.exs` is the model). Known timing flakes in
`npc_events_integration_test.exs` are ignorable when they pass in isolation.
