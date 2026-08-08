---
name: aesir-units
description: How units and their GenServer sessions work in Aesir - the PlayerSession/MobSession routing-shell architecture and their handler dirs, SessionState vs PlayerState, StateCommit, the Unit behaviour, the shared runtime views (UnitRegistry/SpatialIndex/Broadcast/SnapshotBuilder), the single-writer rule, deferred effects with epoch/token invalidation, and the cross-session deadlock rules. Load before touching any player/mob session, handler, or unit mutation.
---

# Units and their sessions in Aesir

Every live entity (player, mob, NPC) is a `Unit`. Players and mobs each run one GenServer
per instance; both are **routing shells** — the process owns the mailbox and state, all real
work lives in handler modules. Never add inline domain logic to a session module.

## The Unit behaviour

`unit/unit.ex` defines the polymorphic `@behaviour` implemented by `PlayerState`
(`unit/player/player_state.ex`) and `MobState` (`unit/mob/mob_state.ex`). Callbacks:
`get_race/1`, `get_element/1`, `is_boss?/1`, `get_size/1`, `get_stats/1`,
`get_entity_info/1`, `get_unit_id/1`, `get_unit_type/1`, `get_process_pid/1`,
`get_custom_immunities/1`, `to_combatant/1`, `living?/1`, `corpse?/1`. Combat/status/skills
consume units through this behaviour, not by pattern-matching concrete struct keys — do the
same in new code so a skill/status stays caster-generic across players and mobs.

## Shared runtime views (`unit/`)

Sessions publish to and read from ETS-backed shared views; these are the only correct way to
observe another unit without messaging its process:

- **`UnitRegistry`** (`unit/unit_registry.ex`) — ETS snapshot of each unit's authoritative
  state keyed by `{unit_type, unit_id}`, plus PID lookup. `update_unit_state/3` publishes a
  new snapshot; reads are lock-free.
- **`SpatialIndex`** (`unit/spatial_index.ex`) — ETS position/AoI index for proximity queries.
- **`Broadcast`** (`unit/broadcast.ex`) — resolves registry+spatial recipients and pushes
  packets to nearby players.
- **`SnapshotBuilder`** (`unit/snapshot_builder.ex`) — **not session-owned**. `Map.Coordinator`
  (`map/coordinator.ex`) reads registry snapshots and chunks AoI datagrams on its own loop.
  A session mutating its own state does not push world snapshots itself.

## PlayerSession: shell + SessionState + handlers

- `unit/player/player_session.ex` routes tagged `handle_cast/handle_call/handle_info`.
  Decoded client ingress arrives via `ZoneServer.forward_to_player_session/2` →
  `PlayerSession.deliver_message/2` → `{:message, msg}` → `Handlers.PacketHandler.handle_message/2`.
  (Tests inject the same envelope with `simulate_incoming_message/2`; see `aesir-workflow`.)
- **`SessionState`** (`unit/player/session_state.ex`) is the GenServer state. It wraps the
  authoritative immutable **`%PlayerState{}` as `state.game_state`** and adds process-level
  bookkeeping the game state must NOT carry: `connection_pid`/monitor, `client_capabilities`,
  the single-dialog `interaction_lock`, `pending_skill_text_input`/`pending_skill_menu`,
  `deferred_skill_result`, party/guild invite slots, homunculus + `homunculus_runtime`.
  Optional slots are real struct fields (default `nil`) — set/clear with struct updates,
  never dynamic map keys.
- **Every handler threads `SessionState` in and out.** All ~46 handlers live in
  `unit/player/handlers/` grouped by domain: packet routing (`PacketHandler`);
  movement/warp/visibility (`MovementHandler`, `WarpHandler`, `VisibilityHandler`,
  `MapLoadHandler`); combat/vitals (`CombatActionHandler`, `HealthHandler`,
  `NaturalHealHandler`); skills (`SkillHandler`, `SkillLearningHandler`, `SkillMenuHandler`,
  `SkillTextInputHandler`, `SpiritSphereHandler`, `SpiritExchangeHandler`); stats/status/
  progression (`StatsManager`, `StatusManager`, `StatAllocationHandler`, `ExperienceHandler`,
  `ProgressionHandler`); inventory/items (`InventoryManager`, `InventoryOps`,
  `InventoryStaging`, `EquipmentHandler`, `ItemHandler`, `BreakOps`, `RefineOps`,
  `PickupHandler`, `LootHandler`); cart/storage/vending (`CartHandler`/`CartOps`,
  `StorageHandler`/`StorageOps`, `VendingHandler`); NPC/social (`NpcInteractionHandler`,
  `NpcShopHandler`, `NpcOwnerEventHandler`, `ScriptEffectHandler`, `PartyHandler`,
  `GuildHandler`, `SocialHandler`); appearance (`MountHandler`, `FalconHandler`,
  `ChatHandler`, `EmoteHandler`, `NameHandler`).
- **Committing state**: when a handler produces a new `PlayerState`, publish it with
  **`StateCommit.commit/2`** (`unit/player/state_commit.ex`) — it writes the snapshot to
  `UnitRegistry` and best-effort-syncs party/guild views, returning the session carrying the
  new `game_state`. Party/guild sync never rolls back the authoritative session/registry.
- **Movement completion** is shell-level cross-domain routing keyed by
  `{action_state, movement_intent}`; movement also fires status `on_movement_intent`
  callbacks (`handlers/movement_handler.ex`) — e.g. Cloaking reacts to intent there.

## MobSession: shell + handlers

- `unit/mob/mob_session.ex` is a shell over `unit/mob/handlers/`: **`AiHandler`** (AI tick /
  sleep-wake / targeting), **`CastingHandler`** (cast lifecycle), **`CombatHandler`**
  (damage/death), **`MovementHandler`** (path/ticks/teleport/displacement). Put logic in
  handlers, never new inline session clauses.
- The AI loop is self-armed: `{:ai, :tick}` is rescheduled by `AiHandler`; `AiStateMachine`
  (`unit/mob/ai_state_machine.ex`) is a pure functional patrol/aggro/chase/attack/flee FSM
  (`gen_state_machine` is a listed dep but intentionally unused).
- Mob cast state is real: `CastingHandler.begin_cast/3` stores the row + timer, completion
  executes or aborts, `abort_cast/1` cancels the timer, broadcasts cancel, applies cooldown,
  and clears the descriptor (silence/stun interruption works). See `aesir-mobs`.

## Single-writer rule (the load-bearing invariant)

- A player/mob is mutated **only through its own mailbox/handlers**. Never write another
  entity's live state directly, and never `GenServer.call(self(), ...)` from inside a
  handler (self-call deadlock) — continue deferred work with self-`send`/`cast` instead.
- **`StatusStorage` is the deliberate exception** — it is *not* single-writer: debuffs write
  a target's status rows cross-process, and immobilization is pull-based (`can_move?`/
  `can_attack?` checked per action/tick), so no session needs a synchronous notification.
- **No cross-session transactions.** Do not build offer/claim or two-phase-commit protocols
  between `PlayerSession`/`MobSession` to coordinate a cross-unit effect (the Monk Root one
  was deleted as unnecessary complexity). When an effect must be granted exactly once, use
  the synchronous atomic claim `StatusStorage.take_status/3` inside the acting process, then
  write both sides' rows directly; let ticks + finite durations self-heal a dead peer.
- **Cross-session synchronous calls need an explicit ownership/order design.** Example: MVP
  reward delivery runs *outside* the dying mob's process (`unit/mob/mvp_reward.ex`)
  specifically to avoid a reciprocal player↔mob deadlock during the death path.

## Deferred effects and invalidation

- Effects that must run later in the acting unit's own session go through the generic seam
  `Skill.defer/3` (`mmo/skill.ex`), which schedules `{:skill, {:deferred, module, payload}}`
  on the *current* session. Both shells invoke `module.deferred/2` (an `Active` callback)
  with the current snapshot and retain their session state (`player_session.ex`,
  `mob_session.ex`). **Never add per-skill clauses to a session** — `session_hygiene_test`
  forbids concrete `Mmo.Skills` references in the session modules.
- Deferred / delayed work that can be invalidated must carry an **epoch or token** captured
  at schedule time and re-checked at run time: cast completion uses a cast token, combo/
  spirit timers use generation counters, and mob death/teleport advances a `deferred_epoch`
  so stale deferred effects no-op. When you add delayed work whose target may vanish or move
  on, stamp and check one of these rather than assuming the world is unchanged.

## `session_hygiene_test`

`test/aesir/zone_server/unit/session_hygiene_test.exs` statically guards the shell
architecture: permanent catch-all clauses for unknown cast/info messages, the generic
deferred seam (no concrete skill aliases in sessions), and restricted homunculus aggregate
replacement. If a change to a session module trips it, the fix is almost always "move this
into a handler / behind the deferred seam", not "loosen the test".

## Related skills

- `aesir-workflow` — the single-writer conventions in context, and how to test sessions
  without flakes (integration isolation, `simulate_incoming_message`, determinism rules).
- `aesir-skills` — skills run inside these sessions (`on_place` self-call hazard, deferred).
- `aesir-status-effects` — `StatusStorage` semantics and process placement of callbacks.
- `aesir-mobs` — mob AI, mob cast state, and mob-skill execution.
