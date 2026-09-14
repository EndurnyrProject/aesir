---
name: aesir-npc
description: How to create and refactor NPCs in Aesir - the declarative Npc module + Script DSL, module documentation and credits, behavior-preserving refactors, dialog/effect/read ops, On-events, script variables, and importer ownership protection. Use when writing, porting, documenting, or refactoring NPCs, warps, or NPC script buildins.
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

## NPC module documentation

Start with one sentence describing the NPC's purpose. Add a short `Behavior` section for
meaningful interactions, progression, rewards, or transfers; omit it for simple signs and greetings.
Describe actual behavior, not implementation helpers. Keep maps and coordinates in `spawn`, rather
than duplicating them in documentation.

For imported NPCs, verify authors against the original script's author header and changelog.
do not infer authorship from the latest Git
committer. Preserve verified credits and accurately state the Elixir adaptation's provenance:

```elixir
@moduledoc """
ONE SENTENCE

## Behavior

- Behaviour 1
- Behaviour 2
- ...

## Credits

- Original from rAthena, authors and Contributors 
  - Author 1
  - Author 2
  - ...

## Adaptation

- Transpiled by mix aesir.import.npcs from rAthena script
- LLM-assisted Elixir refactor reviewed by <your name>
"""
```

The credits above are specific to the novice training script. Use each NPC's verified authors,
and include the LLM note only when it describes the actual adaptation. Do not label original
Aesir content as imported.

## Refactoring imported NPCs

1. **Read the complete flow first.** Use the manifest to locate the original source and compare
   the generated module with it. Identify dialogue pages, menu loops and exits, variable gates,
   rewards, random choices, and the order of side effects. Keep bug fixes separate from a
   behavior-preserving refactor; flag existing quirks instead of silently changing them.
2. **Use ordinary Elixir.** Replace generated `ctx = ...; ctx` wrappers, deeply nested `if`s,
   numbered variables, and `loop_1`-style helpers with pipelines, descriptive variables,
   function clauses, `case`/`cond`, and small purpose-named private functions. Share genuinely
   repeated dialogue locally. Prefer interpolation for known strings; retain compatibility
   conversions when their coercion matters. Do not introduce a new interpreter or generic
   framework to refactor a handful of NPCs. Alias `Script.Ctx` and add callback specs.
3. **Preserve exits and effect order.** `close/1` returns the context; it does not throw.
   Generated `throw({:script_end, ctx})` calls implement early exits. Replace them with terminal
   branches or helper returns, not simple deletion that allows fallthrough. Keep post-close
   effects such as `savepoint` and `warp` reachable, preserve page/menu boundaries, and retain
   existing fallback branches and random-choice behavior.
4. **Keep placements intact.** Preserve module names, scopes, event labels, maps, coordinates,
   sprites, directions, and unique names. Identical coordinates on different maps are distinct
   placements, not duplicates to remove. Map renaming is a separate explicit change: check the
   actual map cache and agree on the mapping first. 
5. **Keep importer protection intact.** Hand edits are detected by comparing file contents with
   the manifest's original `output_hash`, not by a comment or a handmade flag. Leave the manifest
   and its generated hashes unchanged during a hand refactor. Updating a hash to match the edited
   file would make it overwritable again. `--force` bypasses only the source-unchanged check;
   edited files still divert to `_conflicts/`. Do not regenerate the corpus as a refactoring step.
6. **Verify proportionally.** Review dialogue/exit paths, reward and variable changes, and all
   placement records against the pre-refactor version. Use the existing test coverage and follow
   the validation gates in the `aesir-workflow` skill; respect requests not to add NPC tests.
   If edits are delegated, only the coordinating agent runs Mix commands, serially, never
   concurrent builds or test suites. For documentation-only edits, check formatting and confirm
   runtime code is unchanged rather than rerunning gameplay suites.

## The Script DSL (`script/dsl.ex`)

All ops thread a `Script.Ctx` (fields: `char_id`, `account_id`, `game_state`, `source`,
`npc_gid`, `session_pid`, `vars`, ...). Three families:

- **Dialog primitives** — `mes/2` buffers text without blocking. `next/1`, `select/2`, and
  `input/2` flush a page and suspend the `Script.Interaction` Task until the client responds.
  `close/1` flushes a `CLOSE` frame and returns the context without blocking or throwing;
  subsequent pipeline effects still run.
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
- Generated and hand-written files share `content/npc`. A manifest record alone does not make a
  file safe to delete: it may have been hand-refactored since generation. For any explicitly
  approved cleanup, remove only files whose current hash still matches the recorded generated
  `output_hash`; preserve edited files and their records. Do not delete the directory or discard
  the manifest to work around conflicts. Corpus regeneration is separate from NPC refactoring.
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
