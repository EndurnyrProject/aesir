---
name: aesir-npc
description: How to create NPCs in Aesir - the declarative Npc module + Script DSL, dialog/effect/read ops, On-events (touch/timer/mob-death), script variables, and the rAthena NPC transpiler workflow (mix aesir.import.npcs, CommandMap, manifest). Use when writing or porting NPCs, warps, or NPC script buildins.
---

# Creating NPCs in Aesir

## Hand-written NPCs

NPCs are declarative Elixir modules under
`apps/zone_server/lib/aesir/zone_server/content/npc/<map>/<name>.ex` with no compile-time
engine coupling:

```elixir
defmodule Aesir.ZoneServer.Content.Npc.Morocc.TurbanThief do
  use Aesir.ZoneServer.Npc,
    spawn: [%{map: "morocc", x: 208, y: 90, dir: 6, sprite: 58, name: "Turban Thief"}]

  @impl true
  def on_talk(ctx) do
    ctx
    |> mes("Want to buy?")
    |> select(["Yes", "No"])
    |> handle_choice()
  end
end
```

- `spawn:` placements: `%{map, x, y, dir, sprite, name}` plus optional `unique_name`
  (rAthena exname, used for `donpcevent "Name::Label"` resolution) and `trigger: {xs, ys}`
  (OnTouch rect half-extents).
- Callbacks: `on_talk/1` (required), `on_init/1` and `on_event/2` (optional). `events/0` is
  auto-derived from `on_event/2` **literal** clause heads (non-literal head = CompileError).
- `Npc.Registry` (`:persistent_term`) indexes placements at boot with deterministic
  synthetic gids from `{map, x, y}`; `Npc.Verifier` fails boot on cell collisions.
- Warp portals are data, not modules: `apps/zone_server/priv/db/warps/*.yml`.

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

`mix aesir.import.npcs [<rathena_root>] [--only <glob>] [--force]` transpiles rAthena
`npc/**/*.txt` into DSL modules (rathena checkout: `~/Development/personal/rathena`).
Output mirrors the rAthena source path — directory plus file basename
(`content/npc/<dir>/<file>/<slug>.ex`, module `Content.Npc.<Dir…>.<File>.<Name>`), so every
NPC in one source file shares a folder and module parent; distinct from hand-written NPCs at
`content/npc/<map>/<name>.ex`.
Pipeline lives under `npc/transpiler/`; state in `priv/npc_transpile/manifest.json`; stub
report at `priv/npc_transpile/_transpile_report.md`.

Rules that repeatedly bite:

- `--only` globs are relative to `npc/` (so `re/jobs/1-1/*`), and the task writes relative
  to CWD — **run from the repo root**, or output nests wrongly.
- `--force` is **required after any transpiler/codegen change** (the manifest skips on
  source hash alone; a codegen fix never propagates otherwise).
- Manifest gotchas: deleting a generated file while its manifest record remains diverts the
  next run to `content/npc/_conflicts/` — drop the manifest key too. Hand-edited outputs
  always divert to `_conflicts/`.
- Only a curated set (~972 manifest entries) is committed. A full-corpus run generates ~10k
  throwaway files and balloons the manifest — measure, then revert the manifest and clean
  the untracked output; never commit the mass output.
- Unsupported buildins become runtime-raising `todo(ctx, :name, args)` stubs. Implementing
  one = add a DSL op + a `CommandMap` entry (or `@call_reads`/`@functions` for reads and
  global callfuncs), then force-regen. Codegen-native reads must also be added to Analyzer
  `@native_cmds` — keep the two in sync. Buildin lookups are case-insensitive; `read/1`
  params and `function/1` names are case-sensitive.
- Global rAthena functions map onto DSL primitives via `CommandMap.function/1`
  (`Job_Change` → `jobchange` is the template).

## Testing

Mirror the existing end-to-end tests (`test/integration/npc_events_integration_test.exs`,
quest/warp integration tests). Sharp edge: `IntegrationCase.setup_ets_tables/1` shares the
boot-time UnitRegistry/SpatialIndex with the live prontera Coordinator — movement/warp
scenarios must isolate via `Aesir.TestEtsSetup.setup_ets_tables/1`. Var tests need
`DataCase` + `setup_ets_tables` (`dsl_vars_test.exs` is the model). Known timing flakes in
`npc_events_integration_test.exs` are ignorable when they pass in isolation.
