---
name: aesir-mobs
description: How to work on mobs in Aesir - MobSession/AI, the mob and spawn databases, and the mob skill system (trigger rows, Executor dispatch through the real skill catalog, denylist). Use when adding mobs, spawns, mob AI behavior, or mob skill rows.
---

# Mobs and mob skills in Aesir

## Data and runtime

- Mob DB: `apps/zone_server/priv/db/re/mobs/mobs.yml` (`mix aesir.import.mobs`), loaded into
  `:persistent_term` via `Mmo.MobManagement.Mobs`. Boss/MVP classification is data-driven
  (two-axis: boss-flag vs MVP).
- Spawns: `priv/db/re/spawns/<map>.yml` (`mix aesir.import.spawns`); map `Coordinator` owns
  spawning and the death path.
- Runtime: `unit/mob/mob_session.ex` — one GenServer per mob instance with a self-armed AI
  tick loop; `AiStateMachine` is a pure functional state machine (patrol/aggro/chase/attack/
  flee). MobSession is a routing shell over the handlers in `unit/mob/handlers/` — `AiHandler`
  (tick/sleep-wake/targeting), `CastingHandler` (cast lifecycle), `CombatHandler` (damage/
  death), `MovementHandler` (path/ticks/teleport/displacement). Put logic in handlers, never
  new inline session clauses (`session_hygiene_test` guards this). See `aesir-units` for the
  full shell/handler + single-writer model shared with `PlayerSession`.
- Mob statuses share the player `StatusStorage`; mob vitals never touch `UnitRegistry`.
- Mobs have real cast state via `CastingHandler`: `begin_cast/3` / `abort_cast/1` (silence/
  stun interrupt works), cooldowns keyed by skill_id, and `{:skill, {:deferred, module,
  payload}}` handling.
- **Death path is deadlock-sensitive**: work that touches a player (e.g. MVP reward delivery,
  `unit/mob/mvp_reward.ex`) runs *outside* the dying mob's process to avoid a reciprocal
  player↔mob deadlock. Delayed/deferred work advances a `deferred_epoch` on death/teleport so
  stale effects no-op — stamp and re-check an epoch/token for anything that can outlive the mob.

## Mob skills: one skill system, not two

There is no separate mob-skill implementation layer (the old archetype system was deleted).
The split is:

- **Trigger layer** — `mmo/mob_skill/` (`Db`, `Importer`, `Selector`, `CastingHandler`):
  the imported rows (`priv/db/re/mob_skills/`) own cast time, rate, state conditions, target
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

## Verification

- Known flake: `mob_session_skill_cast_test.exs` cast-interruption case under full-suite
  load (passes in isolation — ignorable when lone).
- Steal/loot: `MobSession.attempt_steal/3` with atomic `MobState.stolen_from`; `:boss`
  excluded.
