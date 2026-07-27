---
name: aesir-skills
description: How to implement job/player skills in Aesir - the Skill behaviour and catalog, Interpreter entry points, ground skill units, deferred effects, mob casting, skill trees, and the testing conventions that catch this subsystem's bug classes. Use when adding or changing game skills (SM_BASH, MG_COLDBOLT, ...).
---

# Implementing skills in Aesir

## Where skills live

- One module per skill under
  `apps/zone_server/lib/aesir/zone_server/mmo/skills/<job>/<skill_name>.ex`
  (e.g. `mage/mg_coldbolt.ex`). Shared helpers in `skills/shared/`, mob-only skills in
  `skills/npc/`.
- `use Aesir.ZoneServer.Mmo.Skill, id:, name:, display_name:, max_level:, target_type:, ...`
  declares the static `Skill.Definition` (element, range, cast times, sp_cost as per-level
  lists, damage_type/kind, etc. — see `mmo/skill/definition.ex` for all fields).
- **No registration step**: `Skill.Catalog` (`mmo/skill/catalog.ex`) discovers every module
  under `Aesir.ZoneServer.Mmo.Skills` at runtime into `:persistent_term` (`reload/0` after
  edits). Lookups: `Catalog.by_id/1`, `by_name/1` (both return `{:ok, defn} | :error`).
- Learnability comes from the skill tree YAMLs: `apps/zone_server/priv/db/skill_tree/<job>.yml`.
  Skill name atoms are lowercase (`:nv_basic`, not `:NV_BASIC`).

## Behaviours

Declared in `mmo/skill/`:

- **`Skill.Active`** — `cast(caster, target, level, definition)`; optional `validate/4`,
  `deferred/2` (effects that must run later in the caster's session), `mob_cast/5` (raw
  unit-typed target + full mob-skill row), `dynamic_cost/4`, `dynamic_cast_time/4`
  (e.g. instant-cast combo skills). Caster type is `PlayerState.t() | MobState.t()` — don't
  pattern-match `%{character_id: _}` unless the skill is deliberately player-only (that's
  what forces a denylist entry for mobs).
- **`Skill.Passive`** — optional bonus callbacks (`atk_bonus/2`, `hit_bonus/2`, ...),
  `attack_proc/2` (carries `:chance`), `attack_replacement/2`, `skill_rider/4` (e.g. Fatal
  Blow riding Bash).
- Ground and menu skills have their own module sets under `mmo/skill/ground*` and
  `mmo/skill/unit*` (see below) — the catalog indexes active/ground/passive/menu separately.

## Interpreter entry points (never add bypass booleans)

`Mmo.Skill.Interpreter` (`mmo/skill/interpreter.ex`) has three narrow entry points:

- `cast/4` — player-initiated, full `validate_cast` chain (learned, SP, catalysts, cooldown).
- `auto_cast/4` — status procs; keeps only the SP charge.
- `item_cast/4` — `itemskill` from item scripts; bypasses every requirement but still
  validates shape (definition, max level, target, range, module `validate/4`) and arms
  cooldown + aftercast delay.

A new restricted cast path = a new narrow entry point with a doc listing exactly what it
skips. Non-consuming runs share `run_unconditional/5` (not `run_cast/5`, which eats
catalysts).

**Range gate**: the Interpreter is the authority on skill range (checked at begin_cast AND
complete_cast). The combat layer re-checks distance with the caster's *weapon* range
(rod = 1), so any direct-target skill whose range the interpreter validated must pass
`skip_range: true` in its `Combat.execute_magic_attack`/`execute_skill_attack` opts, or
casts silently fizzle at range (the fizzle is a debug-level log only). Bow skills with
`range: -1` are safe. Physical skill attacks roll hit/flee; pass `report_hit: true` and gate
rider effects on the returned `hit?` when the skill has on-hit riders.

## Ground skills (skill units)

Placement flows cast → Interpreter → `Skill.Unit.place/4` → `place_group/2` → the skill's
`on_place/1`.

- **`on_place/1` runs inside the caster's own PlayerSession** — any caster lookup there
  (e.g. `Combat.resolve_combatant(caster_id)`) is a self-call deadlock. Read the caster cell
  from `%Group{origin: {px, py}}` (stamped by `place_group/2`; fall back `origin: nil ->
  {1, 0}` for direction math). `on_interval`/`on_touch` run in `Skill.Unit.Manager` and may
  resolve the caster safely. (`TargetResolver.get_player_unit_state/1` now self-heals the
  self-call case via the UnitRegistry snapshot, but don't rely on it from `on_place`.)
- Per-level data arrays (durations etc.) must cover every level a mob row can cast
  (mob rows carry levels past 10 — an out-of-range level nil-crashes `on_place`).

## Deferred effects

Effects that must run later in the caster's session go through the generic seam:
`Skill.defer/3` + the optional `Active.deferred/2` callback. Never add per-skill clauses to
`PlayerSession`/`MobSession` — `session_hygiene_test` forbids `Mmo.Skills` references in
sessions. MobSession handles `{:skill, {:deferred, module, payload}}` too.

## Skill-staged dialogs (client menus without new proto messages)

When a skill needs a client menu (arrow crafting style): `cast/4` stages a dialog module on
`PlayerState.pending_interaction`; the handler's `drain_interaction` starts a
`Script.Interaction` with synthetic gid `0x6000_0000` and takes the interaction lock. Reuse
this before inventing new wire messages.

## Mob casting

Mobs cast real skill modules via `Mmo.MobSkill.Executor` (see the `aesir-mobs` skill for the
trigger layer). When writing a skill, either keep `cast/4` caster-generic or add a
`mob_cast/5` clause; a player-only pattern-match means adding the skill to
`MobSkill.Denylist` with a reason.

## Testing conventions

- Bugs in the session-execution class (deadlocks, message routing) only reproduce when the
  cast goes through the real session: use `simulate_incoming_message` in integration tests,
  not direct `Skill.cast/4` from the test process.
- Use real `PlayerState`/`MobState`/`UnitRegistry` shapes, not hand-built maps — synthetic
  `attack_info`/entity fixtures have hidden wrong-field and boss-gate bugs.
- Bare `%PlayerState{character_id: id}` fixtures have `stats: nil`; keep code nil-tolerant
  rather than inflating fixtures.
- Mimic stubs: after changing a stubbed function's arity, sweep and update every stub
  (old-arity stubs go silently inert).
- rAthena research: renewal skill logic is under `rathena/src/map/skills/<job>/`, not just
  `skill.cpp`. Keep rAthena pointers out of Aesir code/docs — describe the mechanic.
