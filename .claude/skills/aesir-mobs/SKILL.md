---
name: aesir-mobs
description: How to work on mobs in Aesir - MobSession/AI, the mob and spawn databases, and the mob skill system (trigger rows, Executor dispatch through the real skill catalog, denylist). Use when adding mobs, spawns, mob AI behavior, or mob skill rows.
---

# Mobs and mob skills in Aesir

Mob skills are real skills: an `NPC_*` module must match its rAthena implementation
(`src/map/skills/npc/`, both modes' `skill_db.yml`) exactly, including the ratio per level,
hit-rate bonuses, status chance and the skill's own duration (`AGENTS.md`, "Mechanics
Parity"). A mob row naming a skill with no module is skipped, which is itself a gap to fill.

## Data and runtime

- Mob DB: `apps/zone_server/priv/db/<mode>/mobs/mobs.yml` (`mix aesir.import.mobs`) — mode
  dir is `re/` or `pre-re/` per `AESIR_DB_MODE` (see `aesir-game-modes`); loaded into
  `:persistent_term` via `Mmo.MobManagement.Mobs`. Boss/MVP classification is data-driven
  (two-axis: boss-flag vs MVP).
- Spawns: `priv/db/<mode>/spawns/<map>.yml` (`mix aesir.import.spawns`); map `Coordinator` owns
  spawning and the death path.
- Runtime: `unit/mob/mob_session.ex` — one GenServer per mob instance. The hard think
  (`AIStateMachine.process_ai/3`) is driven per player by the map: `Map.Coordinator`'s
  100 ms `:hard_ai_tick` runs `MobSupervisor.drive_hard_ai/2`, sending `{:ai, {:hard,
  player_id}}` to every mob within 18 cells of each player (a mob near two players
  thinks twice). The mob's own 1 s `{:ai, :tick}` runs the lazy think (unlock, random walk
  and idle skills for a spotted mob); the attack timer and a walk-delayed chase resume are
  self-armed messages; the attacked event thinks once. The mob carries its skill state (`MobState.skill_state`:
  `idle/walk/loot/dead/berserk/angry/rush/follow`, set only through `MobState.set_state/2`,
  which resolves attack/chase to their angry forms from `aggressive`) and the AI body is
  one ordered pass: target validity, attacked event, search, random walk or attack/chase/
  immobile fallback. MobSession is a routing shell over the handlers in `unit/mob/handlers/`
  — `AiHandler` (tick/sleep-wake/targeting), `CastingHandler` (cast lifecycle),
  `CombatHandler` (damage/death), `MovementHandler` (path/ticks/teleport/displacement). Put
  logic in handlers, never new inline session clauses (`session_hygiene_test` guards this).
  Tests build mob states with `awake: false` (no tick at all); a test that wants one hard
  think sends `{:ai, {:hard, player_id}}` (`AiHandler.handle_hard_think/2`). See `aesir-units` for the
  full shell/handler + single-writer model shared with `PlayerSession`.
- Mob statuses share the player `StatusStorage`; mob vitals never touch `UnitRegistry`.
- Mobs have real cast state via `CastingHandler`: `begin_cast/3` / `abort_cast/1` (forced
  interrupts such as Spell Breaker), cooldowns keyed by skill_id, and `{:skill, {:deferred,
  module, payload}}` handling. A status landing mid-cast never interrupts it; the cast is
  judged at completion (`Targeting.validate_cast_completion/3`, see `aesir-skills`).
- **Death path is deadlock-sensitive**: work that touches a player (e.g. MVP reward delivery,
  `unit/mob/mvp_reward.ex`) runs *outside* the dying mob's process to avoid a reciprocal
  player↔mob deadlock. Death/teleport advance the mob's `deferred_epoch`; the epoch/token rule
  for delayed work is in `aesir-units`.

## Mob skills: one skill system, not two

There is no separate mob-skill implementation layer (the old archetype system was deleted).
The split is:

- **Trigger layer** — `mmo/mob_skill/` (`Db`, `Importer`, `Selector`, `CastingHandler`):
  the imported rows (`priv/db/<mode>/mob_skills/`) own cast time, rate, state conditions, target
  codes.
- **Execution** — `MobSkill.Executor` resolves `Skill.Catalog.by_id(row.skill_id)` and
  dispatches to the real `Skill.Active` module with a `%MobState{}` caster, calling
  `mob_cast/5` when the module exports it (raw unit-typed target + full row, giving access
  to `condition.val1..val5`), otherwise `cast/4` with an **adapted** target:
  `{:unit, _type, id}` → `{:unit, id}`; ground-type rows re-center onto the target's live
  cell; self-targets become `{:unit, instance_id}` — never bare `:self`.

Rules and gotchas:

- `MobSkill.Denylist` lists skills mobs cannot cast, each with a reason (mostly player-only
  pattern-matches, plus rows whose levels exceed a skill's per-level arrays).
  Un-denylisting = giving the skill a mob-caster clause, not editing rows.
- `Targeting.validate_enemy/2` blocks mob→mob (PvE faction rule) — this is the only thing
  keeping mob-cast ground groups from friendly fire; `apply_skill_unit_damage` has no gate
  of its own. Splash enumeration via `Combat.splash_targets` must receive the **resolved
  caster combatant** — a bare int id is assumed to be a player id and silently drops targets.
- Physical skill attacks roll hit/flee for mobs too; NPC elemental attack modules widen
  `mob_data.attack_range` → skill range before `execute_skill_attack` so chase/angry rows
  fire out of melee.
- Mob→player utility casts are PvE content (mobs cast Dispel etc.) even while the
  player→player equivalents stay PvP-gated.
- Mob-originated statuses on players must pass `source_type: :mob` when applying (see
  `aesir-status-effects`).

## Testing

- Mob skill rows and the denylist are data: test `Executor` dispatch and `mob_cast/5` logic,
  not that a row exists. Cast lifecycle (interrupt, cooldown) is session behaviour and belongs
  in one integration test per path, not per skill. See AGENTS.md "What to test".
- Steal/loot: `MobSession.attempt_steal/3` with atomic `MobState.stolen_from`; `:boss`
  excluded.
