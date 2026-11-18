---
name: aesir-workflow
description: How to work on the Aesir codebase - version control (colocated Jujutsu), the spec-to-implementation flow, the mechanics parity procedure, the proportionality stop, and engineering conventions not owned by another skill. Testing lives in aesir-testing. Load this before starting any non-trivial change in this repo.
---

# Working on Aesir

Aesir is a Ragnarok Online emulator in Elixir: an umbrella of four OTP apps
(`commons`, `account_server`, `char_server`, `zone_server`) talking to a custom Rust client
over QUIC + Protobuf. It serves two first-class rulesets from one artifact, **renewal** and
**pre-renewal** (trans-era classic), selected at boot by `AESIR_DB_MODE`. Correctness in both
modes is the top priority, with zero regression tolerance in either. The research method, the
mode seam, and the writing rules for mode-aware code (including how to cite rAthena) are owned
by `aesir-game-modes`.

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
corresponding skills). Documents live in the Obsidian vault under
`specs/YYYY-MM-DD-<topic>/` as `design.md` and `tasks.md`.
Deferred work is recorded in the spec folder (`deferred.md`); read
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

Lessons from past divergences (all were real bugs) are listed per subsystem: the "Parity
first" traps in `aesir-skills` (SP timing, cast start vs cast end, `RE_LVL_DMOD`, HitCount,
ground-unit cells) and in `aesir-status-effects`.

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

- `mix format` and `mix credo --strict` before considering work done.
- After changing an importer or codegen (items, NPCs), **`mix compile` first**: mix tasks
  have silently run stale dev beams and regenerated output with old code. Sanity-check that
  the output actually changed.
- Everything about tests (what to test, gates, running and reading suites, factories, async,
  Mimic, integration isolation, the flake checklist) is in `aesir-testing`.

## Engineering conventions not owned by another skill

- **Clause budget for generated code**: the BEAM JIT dies above ~6-7k clauses in one function.
  Never generate one clause or module per entry for a corpus that can exceed the budget (the
  item-script case is in `aesir-items`).
- **Restricted entry points over bypass booleans**: when a path must skip validations, add a
  separate narrow entry point documenting exactly what it skips (the skill Interpreter's
  `cast/4` vs `auto_cast/4` vs `item_cast/4`, see `aesir-skills`), never a bypass flag
  threaded through the main validate chain.
- **Sweep the bug class**: when fixing a bug in a table/catalog entry, grep for structural
  siblings (dead modifier keys, missing resolver entries) instead of patching one instance.
  An inert bug can mask a crash; when fixing "this value is never read", check what happens
  once it is.

## Related skills

- `aesir-units`: sessions, handlers, `SessionState`/`StateCommit`, single-writer rule,
  deferred effects with epoch/token invalidation (canonical owner of those rules).
- `aesir-testing`: what to test, gates, factories, async and Mimic rules, integration isolation,
  the flake checklist.
- `aesir-game-modes`: renewal vs pre-renewal research, the mode seam, mode-aware writing rules.
- `aesir-skills`, `aesir-status-effects`, `aesir-items`, `aesir-mobs`, `aesir-npc`,
  `aesir-protocol`: per-subsystem guides.
