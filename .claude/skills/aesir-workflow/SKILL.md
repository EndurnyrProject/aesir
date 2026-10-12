---
name: aesir-workflow
description: How to work on the Aesir codebase - version control (colocated Jujutsu), the spec-to-implementation flow, the proportionality stop, test mechanics (integration isolation, determinism, Mimic sharp edges, flake root causes), and engineering conventions not owned by another skill. Load this before starting any non-trivial change in this repo.
---

# Working on Aesir

Aesir is a Ragnarok Online emulator in Elixir: an umbrella of four OTP apps
(`commons`, `account_server`, `char_server`, `zone_server`) talking to a custom Rust client
over QUIC + Protobuf. It serves two rulesets from one artifact, **renewal** (the flagship)
and **pre-renewal** (trans-era classic), selected at boot by `AESIR_DB_MODE`. Correctness
with respect to the active mode's mechanics is the top priority; renewal has zero regression
tolerance. The research method, the mode seam, and the writing rules for mode-aware code
(including "never cite rAthena in Aesir code or docs") are owned by `aesir-game-modes`.

## Version control: colocated Jujutsu

The repo is colocated jj (`.jj/` next to `.git/`). `git status` showing `HEAD detached` is
jj's normal state, not a problem.

- **All history writes go through `jj`**: `jj commit -m "..."`, never `git add && git commit`.
  Reading with `git log` / `git diff` / `git show` is fine.
- **After committing, advance the bookmark**: `jj bookmark set master -r @-`. Bookmarks do
  not follow new commits; otherwise the work is unreachable from any branch. Feature epics
  use `feat/<name>` bookmarks the same way. When it is ambiguous whether work advances
  `master` or a `feat/*` bookmark, ask.
- The user works on a local `master` well ahead of `master@origin`; nothing is auto-pushed.
- Commit messages: one line (`feat(monk): implement asura strike`). No descriptions, no
  co-authored trailers.
- Workspaces go **inside the repo** at `.worktrees/<name>` (`jj workspace add
  .worktrees/<name>`), never as sibling directories; clean up with `jj workspace forget`.
  Parallel agents must never use `git stash` (the stash is shared across worktrees). After
  rebasing a workspace's `@` from elsewhere, run `jj workspace update-stale` inside it before
  running tests there.

## Feature flow

Non-trivial features follow **brainstorming → generate-tasks → implementing-tasks** (the
corresponding skills). Documents live in the Obsidian vault at
`~/Library/Mobile Documents/com~apple~CloudDocs/vaults/aesir` under
`specs/YYYY-MM-DD-<topic>/` as `design.md` and `tasks.md` (older specs use `spec.md` +
`architecture.md`). Deferred work is recorded in the spec folder (`deferred.md`); read
existing specs before relitigating scope decisions.

### Mechanics parity procedure

The rule is in `AGENTS.md` ("Mechanics Parity"): mechanics are identical to rAthena, no
accepted divergences. How to apply it:

- **Designs quote the source.** A design's mechanics section is written from the rAthena code
  and cites the exact files and cases, never from memory or wikis. Each per-skill task brief
  lists those reference paths.
- **Before coding a skill or status, write its parity checklist** from the source, both modes:
  costs and timing per level, targeting, formula and rounding, every roll and what it is
  rolled against, durations, cast-start vs cast-end effects, what happens on each failure path
  (and whether SP or items are still spent), interactions with other statuses and skills, and
  mob casting. Implement against the checklist, not against the brief's prose.
- **Review against the source.** When dispatching a reviewer for mechanics work, include the
  reference file paths and ask it to compare behaviour with them, not only the acceptance
  criteria. A review finding about mechanics is resolved by reading the source, not by
  reasoning about what the skill is meant to do.
- **`mix aesir.audit.skills` is not a parity check.** It compares database fields only
  (costs, hit counts, splash, element). Logic divergences pass it.
- **Rulings record ambiguities, never divergences.** A `## Rulings` entry may explain how the
  reference was mapped onto Aesir's structure; it may not accept behaving differently.

Lessons from past divergences (all were real bugs):

- SP is consumed **before** the skill's effect (`skill_consume_requirement` type 1), and
  `SKILL_NOCONSUME_REQ` spares items only. A skill whose effect depends on the caster's SP, or
  that fails after the requirement step, must still spend the SP.
- Many statuses react at **cast start** (Foresight charges, pre-renewal Mystical
  Amplification arming, Suffragium), not when the skill resolves.
- `RE_LVL_DMOD` scales only above base level 99; positive HitCount multiplies one damage roll
  (`DAMAGE_DIV_FIX`); cast-time flags (`IgnoreDex`, `IgnoreStatus`, `IgnoreItemBonus`) matter.
- Ground units can have per-cell lifetimes and per-cell placement failures; units already
  standing in a new group's cells are affected at placement.

### Proportionality stop

- No cross-cutting correctness machinery (CAS, version counters, writer protocols,
  transaction coordinators, codebase-wide persistence seams) for a hypothetical race. It
  needs a concrete reproducer, an observed failure, or explicit user approval.
- When a narrow feature starts requiring unrelated writers, handlers, or subsystems to
  migrate, stop and reopen the design. "Now sweep every writer" from a review is evidence
  the boundary is wrong, not permission to expand recursively.
- Before any scope-expanding loop, report the blast radius and ask. Prefer the local
  transaction around rows the feature owns; record the theoretical race as deferred work.
- Delete an unmerged over-engineered stack rather than rescuing it because effort was spent.

## Build, lint, test

What to test and which commands gate a change are defined in AGENTS.md ("Testing
Approach"). This section is the mechanics.

- `mix format` and `mix credo --strict` before considering work done.
- Prefer file and `file:line` runs while iterating. Native includes and `file:line` can
  override tag exclusions; they never change the runtime mode.
- After changing an importer or codegen (items, NPCs), **`mix compile` first**: mix tasks
  have silently run stale dev beams and regenerated output with old code. Sanity-check that
  the output actually changed.

### Integration test isolation (per-test worlds)

`Aesir.ZoneServer.IntegrationCase` (`test/support/integration_case.ex`) gives each test its
own ETS world and background processes. Never reach for the boot-global
`MapManager`/`Coordinator`.

- `use ExUnit.Case, async: false`; setup calls `Mimic.set_mimic_private()`, seeds a fresh
  random `EtsTable`, starts per-test unnamed `StatusTickManager`, skill-unit manager, and
  NPC interaction supervisors, plus an isolated `"prontera"` world.
- Any other map: `start_per_test_map(@map)` in `setup` (unnamed `MobSupervisor` +
  `Coordinator`, scoped through `ProcessTree`, auto-cleaned). Do not add
  `MapManager.get_coordinator/1` wait/retry helpers; a few legacy `ensure_coordinator`
  privates still target global state, do not copy them.
- `Aesir.TestEtsSetup.setup_ets_tables/1` is the unit-test seeded-ETS helper;
  `IntegrationCase` includes that seeding, so integration tests use `IntegrationCase` only.
- Helpers (`test/support/`): `simulate_incoming_message/2` (packet ingress),
  `start_player_session/1` / `start_mob_session/1` (accept `vit:`/`luk:`; mobs also
  `agi:`/`dex:` and default `awake: false` to avoid idle-AI wander flakes),
  `assert_packet_sent/2` / `collect_packets_of_type/2`, and `assert_eventually`/`eventually/3`
  (`commons` `test_wait.ex`, polls 25ms/4s). Use these instead of `Process.sleep`.
- `assert_packet_sent` timeout trap: `collect_packets_of_type` restarts its timeout after
  every matching packet, so it waits the full timeout after the *last* match. Keep the
  100ms default; raising it starves time-sensitive follow-up effects.

### Determinism (the flake checklist)

Every flake the suite has had traces to one of these. Check them before diagnosing a race.

- **Unpinned infliction rolls** are the most common cause. A status applied through the real
  path as arranged state must be pinned: `vit: 0, luk: 0` on the target (rolls in a
  session/manager process), or `stub(Resistance, :roll_success, fn _ -> true end)` when the
  roll happens in the test process (`Resistance` is Mimic-able via `test_helper.exs`).
- **Unpinned swing rolls**: a critical skips the hit roll, a player defender always has a
  Lucky Dodge chance, and the hit rate never guarantees a miss. A test that needs a hit or a
  miss pins the outcome (`stub(HitCalculations, :calculate_hit_result, ...)`) or the crit
  (`critical_rate: 0`) when the attack runs in the test process.
- **Deadlines stamped inside the call**: assert `expires_at` between `before + d` and
  `after + d` around the call, never `assert_in_delta expires_at - now`, which drifts
  under load.
- **Mimic mode leak**: a file that stubs without claiming a mode inherits whatever the
  previous module leaked. Files that stub need `setup :set_mimic_private`; files that go
  global need `setup {Aesir.MimicMode, :global}`, never raw `setup :set_mimic_global`.
  `IntegrationCase` claims private mode per test; a module-level global setup still wins.
- Knockback/pull is a `GenServer.cast`. Asserting immediately after arranging a displacement
  races the mover's landing, and whatever occupies the destination cell can fire `on_touch`.
- Snapshotting a whole `SessionState` and pinning it across an operation also pins
  lazily-populated fields (`quest_info_display` is filled by an async post-map-load refresh).
  Let the session settle with `assert_eventually` before the snapshot.
- `spawn(fn -> :ok end)` + `Process.monitor` delivers `:noproc`, not `:normal`, when the
  process exits first; never pin that DOWN reason.
- `ClusterTestHelper.clear_all/0` waits for terminated Horde owners to leave the local ETS;
  anything else tearing down cluster entries needs the same wait.
- Generated `userid`s must be ≤23 chars (account validation); use short prefixes.
- Parallel worktree suites share one `aesir_test` database; concurrent runs exhaust
  Postgres connections and surface as one-off DB failures. Check how many suites are running.
- Remaining known flake: `test/integration/npc_events_integration_test.exs`
  (OnTimer/OnMyMobDead timing). Ignore when gating on green if it passes in isolation.

### Mimic and fixture sharp edges

- **Arity trap**: changing a stubbed function's arity silently deactivates every old-arity
  stub; the real function runs and tests pass for the wrong reason. After any arity change:
  `rg 'stub\(TheModule|expect\(TheModule' apps/*/test` and update all of them. The tell:
  `assert_received` failing on a message a stub should have sent.
- **Use real production shapes** in status/combat tests. Hand-built `attack_info` maps and
  hardcoded entity fixtures have hidden real bugs (wrong field names, boss-flag gates).
  Insist on real `UnitRegistry`/`PlayerState`/`MobState` shapes; bare
  `%PlayerState{character_id: id}` fixtures have `stats: nil`, so keep code nil-tolerant
  rather than inflating fixtures.
- Tests driving `PlayerSession.init`/`terminate` directly must `Mimic.copy(StatusPersistence)`
  and stub `restore_on_spawn`/`save_statuses`, or they hit the DB sandbox.
- Deadlock-class bugs (self-calls inside a session) only reproduce when the cast goes
  through the real session (`simulate_incoming_message`), never when the test process calls
  `Skill.cast/4` directly.
- Keep `defdelegate` seams when splitting modules so existing Mimic stubs keep working.

## Engineering conventions not owned by another skill

- **Interpreted content, never generated modules**: item scripts and NPC scripts compile to
  interpreted AST/IR. The BEAM JIT dies above ~6-7k clauses in one function; the corpus
  needs ~14k. Do not reintroduce per-item/per-NPC generated modules.
- **Runtime catalogs in `:persistent_term`** with a `reload/0` (`Items`, `Mobs` are the
  canonical shape); never bake large data into compile-time module attributes.
- **Restricted entry points over bypass booleans**: when a path must skip validations, add a
  separate narrow entry point documenting exactly what it skips (the skill Interpreter's
  `cast/4` vs `auto_cast/4` vs `item_cast/4`, see `aesir-skills`), never a bypass flag
  threaded through the main validate chain.
- **Sweep the bug class**: when fixing a bug in a table/catalog entry, grep for structural
  siblings (dead modifier keys, missing resolver entries) instead of patching one instance.
  An inert bug can mask a crash; when fixing "this value is never read", check what happens
  once it is.
- rAthena research: skill logic is modular under `rathena/src/map/skills/<job>/`; grepping
  only `skill.cpp` finds the usability check and misses the real logic. Grep both.

## Related skills

- `aesir-units`: sessions, handlers, `SessionState`/`StateCommit`, single-writer rule,
  deferred effects with epoch/token invalidation (canonical owner of those rules).
- `aesir-game-modes`: renewal vs pre-renewal research, the mode seam, mode-aware writing rules.
- `aesir-skills`, `aesir-status-effects`, `aesir-items`, `aesir-mobs`, `aesir-npc`,
  `aesir-protocol`: per-subsystem guides.
