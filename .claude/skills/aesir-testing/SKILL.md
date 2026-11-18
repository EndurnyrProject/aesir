---
name: aesir-testing
description: How to test Aesir - what to test and what not to, the gates per change, running and reading the mode-aware suites, writing tests (case templates, ExMachina factories, async rules, Mimic modes), integration isolation, the determinism (flake) checklist, fixture sharp edges, and the audit bar for existing tests. Load before writing, changing, running, or auditing any test.
---

# Testing Aesir

The suite is large (zone_server alone is over 1000 files) and runs in two modes. Every new
test costs every future run, so test logic, not data or wiring, and keep each file as cheap
and parallel as it can be.

## What to test

- **Unit test**: formulas and mechanics (damage, stats, cast time, resistances), parsers,
  transpilers and compilers, handlers with real branching, catalog and registry invariants (one
  test over the whole catalog, not one per module), and regressions for fixed bugs.
- **Do not unit test**: skill/status/item definition metadata (`id`, `name`, `max_level`,
  `display_name`, flags; the catalog invariant tests cover them), one-line delegations, imported
  or generated data, NPC content (see `aesir-npc`), and Mimic `expect` tests that only mirror
  the implementation's call sequence.
- **Integration test**: one per feature path that crosses a session boundary or needs the real
  routing (deadlocks, packet ingress, NPC interaction, warps, quests), driving the real subsystems
  through `IntegrationCase`. Not one per skill or status.
- A new skill or status module needs a test only for the logic it adds. A module whose behaviour
  is entirely declarative needs none.
- Cover the error paths of the logic you add. Mechanics tests assert rAthena's numbers in both
  modes, derived from the source (its `#ifdef RENEWAL` branches), never from the implementation.

## Gates

- While iterating: the touched files, by `file` or `file:line`.
- Before finishing: the test directories for the touched subsystems in the mode you changed, plus
  `mix format` and `mix credo --strict`.
- The full four-command matrix (`mix test.re`, `mix test.pre_re`, `mix test.integration.re`,
  `mix test.integration.pre_re`) is required only for changes to the mode seam
  (`Mmo.Mechanics`, `GameMode`, `Db.Layout`), shared formulas and combat orchestration, test
  support, or data layout. For everything else, do not run it. "Test support" means a change to
  shared helpers, factories' existing defaults, or `IntegrationCase` behaviour; adding a
  `Mimic.copy` line, a stub in `test_helper.exs`, or a new factory does not count.
- Production code touched by a refactor (struct definitions, specs) also gets the targeted
  integrations that exercise it, in both modes.

## Running tests

- Umbrella root: `mix test.re`, `mix test.pre_re` (unit + doctests), `mix test.integration.re`,
  `mix test.integration.pre_re`. They override an inherited `AESIR_DB_MODE` before boot and
  forward normal test arguments (paths, `--only`). Run them serially, in separate Mix
  invocations.
- Plain `mix test` / `mix test.integration` keep environment-based selection (pre-renewal when
  `AESIR_DB_MODE` is unset, per `config/config.exs`). Run app-level commands with
  `AESIR_DB_MODE=renewal` or `=pre_renewal` set explicitly:
  `cd apps/zone_server && AESIR_DB_MODE=renewal mix test test/aesir/zone_server/guild`.
- Native includes and `file:line` can override tag exclusions; they never change the runtime
  mode.
- A new migration needs `MIX_ENV=test mix ecto.migrate` once before app-level runs (the
  umbrella aliases migrate; app-level runs do not).
- After changing an importer or codegen, `mix compile` first: mix tasks have run stale beams.

**Reading umbrella results.** The aliases run every app in sequence, so `tail` shows only the
last app (`account_server`) and hides zone_server failures. Pipe through this filter once,
never `tail` first:

```sh
mix test.re 2>&1 | rg '^(==> |Result:|Failed:|\s+\d+\) test)'
```

It prints one `==> app` header per app, each `Result:` line, and the `N) test ...` header of
every failure. Re-run only the failing file to see the full output.

### Integration runs

Each integration suite takes about 10 minutes per mode. Treat a full run as expensive.

- **Waves: integrations only at the end of the wave.** While implementing a wave's tasks run
  unit tests, format and credo only; once every task in the wave is done, run the integrations
  once (targeted, then the full suite if required) and fix the fallout before closing the wave.
- **Targeted first.** `rg -l` the touched module, message or skill under
  `apps/zone_server/test/integration` and run only those files, in both modes:
  `mix test.integration.re <files>`, then `mix test.integration.pre_re <files>`.
- **Full suite at most once per wave or change**, only when a gate requires it or the user asks,
  and last, after the targeted files are green.
- **After a full run fails, never re-run the full suite to check a fix.** Re-run the failing
  files in the failing mode; repeat the full suite only if the fix touched shared code again.
- **One mode, then the other**, never both at once (shared `aesir_test` database). A full run
  exceeds the 600 s tool timeout: start it in the background writing to a log file with a
  completion marker, wait once, then filter the log with the `rg` filter above.
- **Flakes**: re-run the one failing file 2-3 times in isolation before treating a failure as
  real, and compare against the known flakes below.

### Mode tags

- Shared unit tests stay untagged and run in both modes. Pure tests calling both formula
  implementations directly stay untagged.
- A test needing a boot mode uses `@tag game_mode: :renewal` or `:pre_renewal`
  (`@describetag`/`@moduletag` for groups).
- `IntegrationCase` gives shared integrations both `integration_re: true` and
  `integration_pre_re: true`. A mode-specific integration must also set its opposite
  integration tag to `false`; a `game_mode` tag alone cannot override an ExUnit include filter.
  Keep paired cases in the same file. Explicit CLI integration selectors must include `:true`,
  because a bare tag also matches a tag set to `false`.

## Writing tests

### Case templates

| Needs | Use |
| --- | --- |
| Pure functions, no DB | `use ExUnit.Case, async: true` |
| DB rows | `use Aesir.DataCase, async: true` (sandbox: own connection when async, shared when sync) |
| Seeded zone ETS for a unit test | `Aesir.TestEtsSetup.setup_ets_tables/1` |
| Sessions, packet ingress, maps, NPCs | `use Aesir.ZoneServer.IntegrationCase` (always sync) |

Follow AAA. Use Mimic for boundaries, never for the function under test.

### Fixtures: factories, not builder functions

Do not write per-file `account_fixture`/`char_fixture`/`state(...)` builders. Use ExMachina:

- **`Aesir.Factory`** (`apps/commons/test/support/factory.ex`, `ExMachina.Ecto`) for persisted
  rows: `insert(:character, name: "Founder", class: 7)`, `insert(:guild)`, `insert(:account)`.
  Parents are built through associations; pass `character: character` to attach to an existing
  one.
- **`Aesir.ZoneServer.Factory`** (`apps/zone_server/test/support/factory.ex`, plain
  `ExMachina`) for in-memory runtime structs: `build(:guild_state, members: [member])`,
  `build(:guild_member, position_index: 5)`, `build_list(16, :guild_member)`.
- The two modules both define `build/2`, so a file imports one. A file needing both imports the
  one it uses most and calls the other qualified (`Aesir.Factory.insert(...)`).
- Add a factory when a struct is built in more than one file. A factory fills only the enforced
  keys and documents its defaults; everything else stays at the struct default so the test
  states what it cares about. Keep a short local helper only when it is a one-line
  parameterisation of a factory call that several tests share.
- **No colliding defaults.** A default must never equal a value a sequence can produce: a
  `master_char_id: 1` default made the first sequenced member the master. Use `0`/`nil` for
  "unset" and let the test set it.
- **No hardcoded ids against sequences.** A "non-member" id of `999` collides once the sequence
  reaches it; derive it (`member.char_id + 1`). Ids a test asserts on are passed explicitly.
- Build the real struct. Never loosen a production `@spec` or function head to `map()` / `%{}`
  so a test can pass a partial map; extend the factory instead. A struct type names its struct
  (`State.t()`, `%State{}`), and an attribute map gets a precise map type.

### Async by default

Every file is `async: true` unless one of these applies; when it does, say which in a comment
only if it is not obvious from the setup.

- **Shared DB sandbox needed**: a process outside the test's `$callers` tree touches the DB.
  Example: the guild Horde `Entry` (started under `Cluster.owner_supervisor/0`) runs
  `Guild.Manager` DB writes inside its reply functions, so `Guild.Manager` tests stay sync.
- **Global teardown**: `ClusterTestHelper.clear_all/0` kills every cluster entry, including
  other tests'. Prefer per-test unique keys (`System.unique_integer([:positive])`) and let
  anchors or `on_exit` drop only what the test made.
- **Global state**: `:persistent_term` reloads (`Data.reload/0`, `DbTestSetup.configure_root/2`),
  `Application.put_env`, writes to boot-global ETS or named processes.
- **DDL**: `ALTER TABLE`/`ALTER SEQUENCE` inside a sandbox takes an exclusive lock that stalls
  every concurrent sandbox touching that table (`fame/store_test.exs`).
- **Global Mimic mode**: a stub that must reach a process started outside the test's tree.
- `IntegrationCase` files are always sync.

Ways to turn a sync file async:

- Unique keys per test instead of a global clear.
- Factory rows instead of hardcoded `userid`/`email`/`name` values: a concurrent insert of the
  same unique key blocks until the other test's sandbox rolls back.
- `Task.start`/`Task.async` propagate `$callers`, so private Mimic stubs and the DB sandbox
  reach them without anything else.
- A GenServer the test starts can be granted access explicitly:
  `Ecto.Adapters.SQL.Sandbox.allow(Aesir.Repo, self(), pid)` and
  `Mimic.allow(Module, self(), pid)`.
- Split a file when only one describe needs global state, if the rest is meaningful work.

ExUnit runs every async module before the sync ones, so a sync module may mutate global state
safely; an async module never may.

### Mimic

- Copy modules once in the app's `test/test_helper.exs` (`Mimic.copy(Module)`), never in a
  test's `setup`: a runtime copy recompiles the module while concurrent async tests call it.
  Many legacy files still copy at runtime; move the line to `test_helper.exs` when you touch one.
- Claim a mode in every file that stubs: `setup :set_mimic_from_context` (private when the
  module is async, global when it is sync). Mimic 2.5 releases global mode in `on_exit`, so this
  is safe in sync files. `setup {Aesir.MimicMode, :global}` is the older equivalent; do not add
  new uses.
- In private mode a stub reaches the test process and processes carrying it in `$callers`
  (tasks). A GenServer started under a supervisor does not see it: use `Mimic.allow/3` or a
  sync file.
- `setup :verify_on_exit!` when the file uses `expect`.
- **Arity trap**: changing a stubbed function's arity silently deactivates every old-arity
  stub; the real function runs and tests pass for the wrong reason. After any arity change:
  `rg 'stub\(TheModule|expect\(TheModule' apps/*/test` and update them all. The tell:
  `assert_received` failing on a message a stub should have sent.
- Keep `defdelegate` seams when splitting modules so existing stubs keep working.

## Integration test isolation (per-test worlds)

`Aesir.ZoneServer.IntegrationCase` (`test/support/integration_case.ex`) gives each test its
own ETS world and background processes. Never reach for the boot-global
`MapManager`/`Coordinator`.

- It is `async: false`; setup calls `Mimic.set_mimic_private()`, checks out a shared sandbox,
  seeds a fresh random `EtsTable`, starts per-test unnamed `StatusTickManager`, skill-unit
  manager and NPC interaction supervisors, plus an isolated `"prontera"` world. A module-level
  global Mimic setup still wins over its private mode.
- Any other map: `start_per_test_map(@map)` in `setup` (unnamed `MobSupervisor` +
  `Coordinator`, scoped through `ProcessTree`, auto-cleaned). Do not add
  `MapManager.get_coordinator/1` wait/retry helpers; a few legacy `ensure_coordinator`
  privates still target global state, do not copy them.
- `IntegrationCase` includes the `TestEtsSetup` seeding, so integration tests use it alone.
- Helpers (`test/support/`): `simulate_incoming_message/2` (packet ingress),
  `start_player_session/1` / `start_mob_session/1` (accept `vit:`/`luk:`; mobs also
  `agi:`/`dex:` and default `awake: false` to avoid idle-AI wander flakes),
  `assert_packet_sent/2` / `collect_packets_of_type/2`, and `assert_eventually`/`eventually/3`
  (`commons` `test_wait.ex`, polls 25ms/4s). Use these instead of `Process.sleep`.
- `assert_packet_sent` timeout trap: `collect_packets_of_type` restarts its timeout after
  every matching packet, so it waits the full timeout after the *last* match. Keep the 100ms
  default; raising it starves time-sensitive follow-up effects.
- Deadlock-class bugs (self-calls inside a session) only reproduce when the cast goes through
  the real session (`simulate_incoming_message`), never when the test process calls
  `Skill.cast/4` directly.

## Determinism (the flake checklist)

Every flake the suite has had traces to one of these. Check them before diagnosing a race.

- **Unpinned infliction rolls** are the most common cause. A status applied through the real
  path as arranged state must be pinned: `vit: 0, luk: 0` on the target (rolls in a
  session/manager process), or `stub(Resistance, :roll_success, fn _ -> true end)` when the
  roll happens in the test process.
- **Unpinned swing rolls**: a critical skips the hit roll, a player defender always has a
  Lucky Dodge chance, and the hit rate never guarantees a miss. A test that needs a hit or a
  miss pins the outcome (`stub(HitCalculations, :calculate_hit_result, ...)`) or the crit
  (`critical_rate: 0`) when the attack runs in the test process.
- **Deadlines stamped inside the call**: assert `expires_at` between `before + d` and
  `after + d` around the call, never `assert_in_delta expires_at - now`, which drifts under
  load.
- **No Mimic mode claimed**: a file that stubs without `set_mimic_from_context` inherits
  whatever mode is current.
- Knockback/pull is a `GenServer.cast`. Asserting immediately after arranging a displacement
  races the mover's landing, and whatever occupies the destination cell can fire `on_touch`.
- Snapshotting a whole `SessionState` and pinning it across an operation also pins
  lazily-populated fields (`quest_info_display` is filled by an async post-map-load refresh).
  Let the session settle with `assert_eventually` before the snapshot.
- `spawn(fn -> :ok end)` + `Process.monitor` delivers `:noproc`, not `:normal`, when the
  process exits first; never pin that DOWN reason.
- `ClusterTestHelper.clear_all/0` waits for terminated Horde owners to leave the local ETS;
  anything else tearing down cluster entries needs the same wait.
- Generated `userid`s must be ≤23 chars (account validation); the factory already complies.
- Parallel worktree suites share one `aesir_test` database; concurrent runs exhaust Postgres
  connections and surface as one-off DB failures. Check how many suites are running.
- Remaining known flake: `test/integration/npc_events_integration_test.exs`
  (OnTimer/OnMyMobDead timing). Ignore when gating on green if it passes in isolation.

## Fixture shapes

- **Use real production shapes** in status/combat tests. Hand-built `attack_info` maps and
  hardcoded entity fixtures have hidden real bugs (wrong field names, boss-flag gates). Insist
  on real `UnitRegistry`/`PlayerState`/`MobState` shapes; bare `%PlayerState{character_id: id}`
  fixtures have `stats: nil`, so keep code nil-tolerant rather than inflating fixtures.
- Tests driving `PlayerSession.init`/`terminate` directly must `Mimic.copy(StatusPersistence)`
  and stub `restore_on_spawn`/`save_statuses`, or they hit the DB sandbox.
- Fixture values that a mapping test reads must differ from the struct defaults (a `false` flag
  or `0` tax passes even when the field is never mapped).

## Auditing existing tests

Use the `test-audit` skill for sweeps. Its bar, applied here:

- A test must fail when the behaviour breaks and pass when internals are refactored.
- Cut: assertion-free probes, absence-of-export checks (`refute function_exported?`), copied
  data, tests whose negative control passes for an unrelated reason, and duplicates of a kept
  test at the outer boundary. Fold near-duplicates into the shared case.
- Keep: independent contracts, credible regressions, mode-specific parity values.
- Never edit an existing test to make it pass without asking the user.
- The per-module cleanup flow: TypedStruct structs, factories instead of builders, async where
  the rules above allow, then the audit.
