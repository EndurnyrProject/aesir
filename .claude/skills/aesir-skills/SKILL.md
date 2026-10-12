---
name: aesir-skills
description: How to implement job/player skills in Aesir - the Skill behaviour and catalog, Interpreter entry points, ground skill units, deferred effects, mob casting, skill trees, and the testing conventions that catch this subsystem's bug classes. Use when adding or changing game skills (SM_BASH, MG_COLDBOLT, ...).
---

# Implementing skills in Aesir

## Parity first

A skill must behave exactly like rAthena in both modes (`AGENTS.md`, "Mechanics Parity").
Before coding, read the skill's reference file under `rathena/src/map/skills/<job>/`, its
cases in `battle.cpp` / `skill.cpp` / `status.cpp` / `unit.cpp`, and both modes' `skill_db.yml`
rows (including `CastTimeFlags`, `DamageFlags`, `Flags`, `Unit`), and write the parity checklist
described in `aesir-workflow`. The task brief's formulas are a summary, not the authority.

Recurring traps, each a past bug:

- **Cost timing.** SP is spent before the effect runs. A skill that fails after the
  requirement step (missed roll, immune target, already affected, HP charge too high) still
  spends SP; return `{:ok, caster, :no_consume}` only to spare items. When the effect reads
  the caster's SP, use the `dynamic_cost/4` pattern (`sp: 0` + `sp_requirement`) and deduct
  the resolved cost in `cast` first (`CgTarotcard`, `PfSoulchange`).
- **Validate vs cast end.** Checks the reference makes at cast end (immunity, undead, target
  state) belong in `cast`, not `validate/4`, or the SP and the cast bar behave differently.
- **Cast end status check.** No status cancels a cast when it starts. A timed cast's
  completion runs `Targeting.validate_cast_completion/3`: stun, freeze,
  sleep and stone fail only a damage cast (`damage_type: :damage`, not ground/self/support),
  silence fails nothing already under way, and the failure is silent with nothing spent.
  Keep `damage_type` equal to the skill_db `NoDamage` flag; it decides this, the castend
  on-skill arming and when-hit procs.
- **Cast start.** Statuses that react to a cast starting run through
  `Caster.on_cast_start/2` (instant casts) and `SkillHandler` (timed casts at bar start).
- **Level modifier and multi-hit.** Use `Combat.LevelModifier.skill_ratio/2` wherever the
  reference uses `RE_LVL_DMOD`; a positive HitCount multiplies one roll.
- **Targeting.** Match the reference `TargetType` (a ground skill is `:ground`, even if a unit
  version would be easier) and its `Flags` (traps, hidden targets, Emperium).
- **Mob casting.** If the reference lets monsters cast it, support it; never narrow targets
  (players only, mobs only) unless the reference does.

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
- Learnability comes from the skill tree YAMLs: `apps/zone_server/priv/db/<mode>/skill_tree/<job>.yml`
  (mode dir `re/` or `pre-re/`; a skill absent from a mode's tree is unreachable in that mode —
  that's how era-gating works, see `aesir-game-modes`).
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

Delayed work that can be invalidated must carry an epoch or token (cast token, combo/spirit
generation counters, mob `deferred_epoch`); the rule, the session shell, and the
single-writer/no-deadlock rules that govern where skill code runs are in `aesir-units`.

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

- Test the logic a skill adds (formula, branching, riders, `validate/4` rejections). Do not
  write catalog-metadata tests (`id`, `name`, `max_level`, `display_name`, module resolves);
  `catalog_discovery_test.exs` already guards every discovered skill. A skill whose behaviour
  is fully declarative (`use` args plus a shared helper) needs no test file.
- Bugs in the session-execution class (deadlocks, message routing) only reproduce when the
  cast goes through the real session: use `simulate_incoming_message` in integration tests,
  not direct `Skill.cast/4` from the test process.
- Use real `PlayerState`/`MobState`/`UnitRegistry` shapes, not hand-built maps — synthetic
  `attack_info`/entity fixtures have hidden wrong-field and boss-gate bugs.
- Bare `%PlayerState{character_id: id}` fixtures have `stats: nil`; keep code nil-tolerant
  rather than inflating fixtures.
- Fixture shapes, the Mimic arity trap, and the determinism checklist are in `aesir-workflow`.
- rAthena research: skill logic is under `rathena/src/map/skills/<job>/`, not just
  `skill.cpp`. Always check for `#ifdef RENEWAL` branches — many skills behave differently
  pre-renewal. Tests assert the reference's numbers; derive expected values from the
  source, never from the implementation. The both-modes `@moduledoc` rule and the no-rAthena-citations rule are in
  `aesir-game-modes`.
