---
name: aesir-workflow
description: How to work on the Aesir codebase - version control (colocated Jujutsu), the spec-to-implementation flow, testing gates and known flaky tests, Mimic sharp edges, and the project's engineering conventions. Load this before starting any non-trivial change in this repo.
---

# Working on Aesir

Aesir is a Ragnarok Online (Renewal) emulator in Elixir: an umbrella of four OTP apps
(`commons`, `account_server`, `char_server`, `zone_server`) talking to a custom Rust client
over QUIC + Protobuf. Correctness with respect to Renewal mechanics is the top priority.
rAthena (checkout at `~/Development/personal/rathena`) is the reference implementation used
during research — but never cite rAthena files/functions in Aesir code, docs, or comments;
describe the mechanic itself in plain terms.

## Version control: colocated Jujutsu

The repo is colocated jj (`.jj/` next to `.git/`). `git status` showing `HEAD detached` is
jj's normal state, not a problem.

- **All history writes go through `jj`**: `jj commit -m "..."`, never `git add && git commit`.
  Reading with `git log` / `git diff` / `git show` is fine.
- **After committing, advance the bookmark**: `jj bookmark set master -r @-` (bookmarks do
  not follow new commits the way git branches do — committed work is otherwise unreachable
  from any branch). Feature epics go on `feat/<name>` bookmarks the same way.
- The user works on a local `master` well ahead of `master@origin`; nothing is auto-pushed.
  When it's ambiguous whether work advances `master` or a `feat/*` bookmark, ask.
- Commit messages: simple one-liners (`feat(monk): implement asura strike`). No long
  descriptions, no co-authored trailers.
- Worktrees/workspaces go **inside the repo** at `.worktrees/<name>`
  (`jj workspace add .worktrees/<name>`), never as sibling directories. Clean up with
  `jj workspace forget <name>`. Parallel agents must never use `git stash` (the stash stack
  is shared across worktrees). After rebasing a workspace's `@` from elsewhere, run
  `jj workspace update-stale` inside it before running tests there.

## Feature flow

Non-trivial features follow: **brainstorming → architect → generate-tasks → implementing-tasks**
(the corresponding skills). Documents live in the Obsidian vault at
`~/Library/Mobile Documents/com~apple~CloudDocs/vaults/aesir` under
`specs/YYYY-MM-DD-<topic>/` as `spec.md`, `architecture.md`, `tasks.md`. Deferred work is
recorded in the spec folder (e.g. `deferred.md`) — read existing specs before relitigating
scope decisions.

### Proportionality stop

Do not build cross-cutting correctness machinery for a hypothetical race or failure mode. A new CAS,
version counter, writer protocol, transaction coordinator, or whole-codebase persistence seam needs
one of: a concrete reproducer, an observed production failure, or explicit user approval of that
specific complexity.

Stop and reopen the architecture when a narrow feature starts requiring unrelated writers, handlers,
fixtures, or subsystems to migrate. A review finding that says “now sweep every writer” is evidence
that the design boundary is wrong, not permission to expand the task recursively. Prefer the local
transaction around rows the feature actually owns; record the theoretical race as deferred work and
revisit it only when real evidence justifies the cost.

Before continuing any scope-expanding review loop, report the file-count/blast-radius increase and
ask whether the invariant is worth it. Delete an unmerged over-engineered stack rather than rescuing
it because work has already been spent.

When researching a mechanic in rAthena: the skill logic is modular under
`rathena/src/map/skills/<job>/` — grepping only `skill.cpp` for a skill id finds the
usability check and misses the real logic. Grep both.

## Build, lint, test

- `mix format` and `mix credo --strict` before considering work done.
- `mix test` runs unit tests; **integration tests are excluded by default** — decide
  deliberately whether they're in scope for your gate (`mix test --include integration` or
  the focused `test/integration/` dir).
- Prefer targeted test runs while iterating; full suite before finishing.
- After changing an importer or codegen (items, NPCs), **`mix compile` first** — mix tasks
  have silently run stale dev beams and regenerated output with old code. Sanity-check the
  output actually changed.

### Known flaky tests (ignore when gating on green, if they pass in isolation)

- `test/integration/npc_events_integration_test.exs` — OnTimer/OnMyMobDead timing.
- `mechanics_supervisor_test.exs` "item scripts are compiled at zone boot" — boot race.
- `mob_session_skill_cast_test.exs` cast-interruption `refute_receive` — timer race under load.
- `guild/manager_test.exs` generally — shared `guild_fixture/1` race.
- Parallel worktree suites share one `aesir_test` database; concurrent runs exhaust Postgres
  connections and surface as one-off DB-test failures. Check how many suites are running
  before diagnosing a race.

## Testing sharp edges

- **Mimic arity trap**: changing a stubbed function's arity silently deactivates every
  old-arity stub — the real function runs and tests pass for the wrong reason. After any
  arity change, `rg 'stub\(TheModule|expect\(TheModule' test/` and update all of them.
  The tell in parallel work: `assert_received` failing on a message a stub should have sent.
- **Mimic global-mode leak**: `set_mimic_global` is only undone when the Mimic server
  processes the owner's `:DOWN`, which races the next test starting. In that window the
  previous test's stubs are still live for every process, and `stub/3` from the new test
  raises "Stub cannot be called by the current process". Symptoms are a mix of that error
  and unrelated integration tests failing on state a leaked stub quietly faked.
  `IntegrationCase` claims a mode per test (`Mimic.set_mimic_private()` in its setup); a
  module- or describe-level `setup :set_mimic_global` still wins because it runs after.
  Plain `ExUnit.Case` files that stub must declare their own mode.
- **Use real production shapes** in status/combat tests: hand-built `attack_info` maps and
  hardcoded `stub_entity_info` fixtures have hidden real bugs (wrong field names, boss-flag
  gates). Insist on real `UnitRegistry`/`PlayerState`/`MobState` shapes.
- Tests driving `PlayerSession.init`/`terminate` directly must `Mimic.copy(StatusPersistence)`
  and stub `restore_on_spawn`/`save_statuses`, or they hit the DB sandbox.
- `IntegrationCase.setup_ets_tables/1` shares boot-time UnitRegistry/SpatialIndex with the
  live prontera Coordinator — movement/warp scenarios must isolate via
  `Aesir.TestEtsSetup.setup_ets_tables/1` or they race its ticks.
- A test that reuses a real map name for its own supervised process races `MapManager`'s
  lazy boot of that map ~500ms after app start — use a fake map name.
- Deadlock-class bugs (self-calls inside a session) only reproduce when the cast goes
  through the real session (`simulate_incoming_message`), never when the test process calls
  `Skill.cast/4` directly.

## Engineering conventions (beyond CLAUDE.md)

- **Single-writer sessions**: `PlayerSession`/`MobSession` are routing shells; all entity
  mutation routes through their handlers. Never write another entity's state directly —
  except `StatusStorage`, which is deliberately not single-writer (debuffs write target
  rows cross-process; immobilization is pull-based via `can_move?`/`can_attack?`).
  Corollary: never build offer/claim or two-phase-commit protocols between sessions to
  coordinate a cross-unit effect (the Monk Root one was deleted) — use a synchronous atomic
  claim on the shared store (`StatusStorage.take_status/3`) in the acting process instead,
  and let ticks + finite durations self-heal a dead peer.
- **Interpreted content, never generated modules**: item scripts and NPC scripts compile to
  interpreted AST/IR. The BEAM JIT dies above ~6-7k clauses in one function; the corpus
  needs ~14k. Do not reintroduce per-item/per-NPC generated modules.
- **Runtime catalogs in `:persistent_term`** with a `reload/0` (`Items`, `Mobs` are the
  canonical shape) — never bake large data into compile-time module attributes.
- **Restricted entry points over bypass booleans**: when a path must skip validations
  (item casts, status procs), add a separate narrow entry point documenting exactly what it
  skips (`Interpreter.cast/4` vs `auto_cast/4` vs `item_cast/4`), never thread a bypass
  flag through the main validate chain.
- **Sweep the bug class**: when fixing a bug in a table/catalog entry, grep for structural
  siblings (dead modifier keys, missing resolver entries) instead of patching one instance.
  An inert bug can mask a crash — when fixing "this value is never read", check what
  happens once it is.
- Keep `defdelegate` seams when splitting modules so existing Mimic stubs keep working.
- The Repo module is `Aesir.Repo` (project CLAUDE.md's `Aesir.Commons.Repo` is wrong).

## Related skills

- `aesir-npc` — NPCs, the scripting DSL, the transpiler.
- `aesir-skills` — implementing job/player skills.
- `aesir-status-effects` — status effect definitions.
- `aesir-items` — item scripts, equip bonuses, importers.
- `aesir-mobs` — mob AI and mob skill casting.
- `aesir-protocol` — adding Protobuf wire messages.
