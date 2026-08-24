---
name: aesir-status-effects
description: How to implement status effects (SC_*) in Aesir - the Definition behaviour and flags, modifier conventions and their guard tests, apply/persistence semantics, and the deadlock/merge hazards specific to this subsystem. Use when adding buffs, debuffs, endows, or any SC_ status.
---

# Implementing status effects in Aesir

## Where effects live and how they register

- One module per effect:
  `apps/zone_server/lib/aesir/zone_server/mmo/status_effect/effects/<name>.ex`, using
  `use Aesir.ZoneServer.Mmo.StatusEffect.Definition, id: :sc_<name>, ...`.
- Register the module in `status_effect/effects.ex`, and if the status is referenced by item
  scripts, add the `SC_*` symbol to `@statuses` in
  `mmo/item_management/rathena_script/resolver.ex` **in the same commit** — a resolved
  symbol without a module fails at runtime with `{:error, :unknown_status}`.
  `resolver_completeness_test.exs` guards this rule.
- `StatusEffect.Registry` indexes definitions; live instances are in `StatusStorage` (ETS),
  ticked by `StatusTickManager`.
- Never trust `end_on_start`/`prevented_by` lists as proof a status exists — check
  `effects/` for the actual file.

## Definition options and flags

`use ... Definition` takes `id:`, `properties:` (`[:buff]`, `[:debuff]`, ...),
`calc_flags:`, `icon:`, `prevented_by:`, `end_on_start:`, plus behavior flags:

- `no_save: true` — not persisted at logout (map-bound, warp-cleared, or rebuilt statuses).
- `no_dispel: true` — survives Dispel (Dispel ends everything else, debuffs included).
- `bypass_boss_immunity: true` — external application to boss-flagged units normally
  rejects; this flag pierces it.
- `remove_on_map_change: true` — cleared by WarpHandler on cross-map warp only.
- `tick_interval:` — **mandatory for any effect overriding `on_tick`**; tickless statuses
  (`tick <= 0`) get `next_tick_at: nil` and never enter the due set.

`end_on_start` is **directional** (fires when the *new* status applies) — mutual exclusion
requires declarations in both directions on both modules, tested pairwise in both orders
(see `weapon_endow_test.exs` for the generated-pairs pattern; the seven weapon-endow
statuses all name each other).

## Callbacks

`id/0` and `metadata/0` come from the macro. Optional hooks (see `definition.ex`):
`modifiers/2`, `on_apply/3`, `on_expire/3`, `on_tick/3`, `on_damage/4` (victim-side),
`on_dealt_damage/4` (attacker-side procs — runs in the attacker's own process; do not
convert to PubSub), `before_weapon_hit/4` (`:continue | {:intercept, term}` — interception
ends the swing pre-Trifecta), `absorb_damage/4`, `on_contact/4`, `dynamic_option/1`.

**Process placement**: `on_apply` runs inside the applier's session (self-call hazards —
resolve units via `TargetResolver`, never GenServer-call your own session); `on_tick` runs
in `StatusTickManager`. `StatusStorage` is deliberately not single-writer: cross-process
writes to a target's rows are the norm, and immobilization-style effects are pull-based
(`can_move?`/`can_attack?` checked per action). For one-shot claims (Lex Aeterna, Root),
use the atomic `StatusStorage.take_status/3`.

## Modifiers

`modifiers/2` returns a map of **additive numeric deltas** merged by `ModifierCalculator`
(numeric collisions sum; non-numeric take the newer value). Conventions:

- val1-driven magnitude: `%{key: instance.val1}`; fixed magnitude: a literal `@modifiers`
  map. Match how the source data drives it.
- Established keys include flat `aspd`, `aspd_rate`, `max_hp_rate`/`max_sp_rate`,
  `atk_rate`/`matk_rate`/`def_rate`/`mdef_rate`, `phys/magic_damage_reduction`,
  `exp_rate`, `varcast_rate`, `sp_cost_rate`, `attack_element`, `element_override`.
- **A key nobody reads is a silent no-op**: when introducing a genuinely new key, wire its
  reader in combat/stats AND add it to `modifier_readers_test.exs`'s `@read_keys` — that
  test statically extracts every emitted key and fails on dead ones.

## Applying and caster identity

- Apply via `StatusEffect.Interpreter.apply_status(unit_type, unit_id, status_id, params)`.
- `loaded: true` (persistence restore) skips immunity/prevention/conflict/resistance gates
  and uses duration as-is.
- **Cross-type appliers must pass `source_type:`** (mob applying to player passes `:mob`;
  ground-unit statuses pass `group.caster_type`). Default resolution assumes a cross-unit
  caster is a player. `ContextBuilder` tolerates a despawned caster (`%{}` stats); the
  target lookup still raises by design.

## Persistence

`PlayerSession.terminate/2` saves persistable statuses to `character_statuses` (consumed on
login by `StatusPersistence.restore_on_spawn/1` — loaded then deleted). Durations persist
as `remaining_ms` (nil = permanent); `state`/`phase` are NOT persisted — `on_apply` must be
able to rebuild them. `source_type` is not persisted either.

## Testing

- Regression tests for apply-path bugs must run the **real** `apply_status` (no boundary
  stub on the function under suspicion) against real unit shapes.
- Tests driving `PlayerSession.init`/`terminate` must stub `StatusPersistence`
  (`restore_on_spawn` identity, `save_statuses` :ok) or they hit the DB sandbox.
- When fixing one status's bug (dead key, missing flag, missing resolver entry), grep the
  whole `effects/` tree for structural siblings — this subsystem's bugs come in classes.

## Game modes

Several SC_ behaviors diverge between renewal and pre-renewal (element-field skills like
Volcano/Deluge/Violent Gale, Steel Body, Kyrie, Angelus scaling, endows — renewal applies
element bonuses as ratio deltas, pre-re multiplies damage). Phase 1 ships renewal behavior
in both modes; when implementing or touching an effect with a known divergence, document
BOTH modes in the `@moduledoc` (the Phase-2 audit inventory). See `aesir-game-modes`.
