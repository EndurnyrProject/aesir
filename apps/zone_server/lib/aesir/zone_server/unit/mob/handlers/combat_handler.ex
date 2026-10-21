defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler do
  @moduledoc """
  Handles a mob's combat orchestration: damage application, damage-log
  bookkeeping, and the death/kill-announcement pipeline. Extracted from
  MobSession to improve modularity and maintainability.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.Endure
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.HitStop
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.AttackedEvent
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.HitSkillEvents
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.Looting
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MvpReward
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Mob.Slaves
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Mob.StateCommit
  alias Aesir.ZoneServer.Unit.Mob.Stats
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @emperium_id 1288

  @doc """
  Applies `damage` to the mob, from `attacker_id` if known.

  A dead mob is no longer a valid target: dropping the hit (the first clause)
  prevents re-running the death path (and re-awarding experience) during the
  ~1s window between death and process termination, while it is still in the
  registry/index. A live mob gets its damage log entry, the attacked event of a
  landed battle hit (`AttackedEvent.schedule/4`), and an HP broadcast to nearby
  players, then falls through to the death path if the hit was lethal.
  """
  @spec handle_apply_damage(integer(), tuple() | integer() | nil, MobState.t()) ::
          {:noreply, MobState.t()}
  def handle_apply_damage(damage, attacker_id, state),
    do: handle_apply_damage(damage, attacker_id, %{}, state)

  @doc "Applies damage with active/passive notification metadata in the owning mob."
  @spec handle_apply_damage(integer(), tuple() | integer() | nil, map(), MobState.t()) ::
          {:noreply, MobState.t()}
  def handle_apply_damage(_damage, _attacker_id, _metadata, %{is_dead: true} = state) do
    {:noreply, state}
  end

  def handle_apply_damage(damage, attacker, metadata, state) do
    state = CastingHandler.interrupt_on_damage(state, Map.put(metadata, :damage, damage))
    {updated_mob, status} = MobState.apply_damage(state, damage)
    current_time = System.system_time(:second)
    attacker_ref = typed_attacker(attacker)
    reward_owner_id = reward_owner_id(attacker_ref)

    updated_mob = maybe_add_aggro(updated_mob, reward_owner_id, attacker_ref, damage)

    updated_mob =
      if Map.get(metadata, :passive?, false) or Map.get(metadata, :status_tick?, false) do
        updated_mob
      else
        Map.put(updated_mob, :last_damage_time, current_time)
      end

    StatusInterpreter.on_damage(
      :mob,
      state.instance_id,
      metadata
      |> Map.put_new(:element, :neutral)
      |> Map.merge(%{
        damage: min(damage, state.hp),
        hp_after: updated_mob.hp,
        max_hp: state.calculated.max_hp,
        attacker: attacker_ref
      })
    )

    # Send HP update packet to nearby players
    SpawnView.notify_hp_update(updated_mob)

    case status do
      :alive ->
        updated_mob = HitSkillEvents.run(updated_mob, damage, attacker_ref, metadata, now())
        AttackedEvent.schedule(updated_mob, damage, attacker_ref, metadata)
        {:noreply, updated_mob |> maybe_hit_stop(metadata) |> StateCommit.commit()}

      :dead ->
        handle_death(
          updated_mob,
          attacker_ref,
          reward_owner_id,
          {MobState.hit_type(state, attacker), MobState.hit_skill(state, attacker)},
          kill_credit(attacker_ref, reward_owner_id)
        )
    end
  end

  defp now, do: System.system_time(:millisecond)

  @doc "Kills a slave only when the death belongs to its current master."
  @spec handle_master_death(integer(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_master_death(master_id, %MobState{master_id: master_id} = state)
      when is_integer(master_id),
      do: handle_apply_damage(state.hp, nil, %{passive?: true}, state)

  def handle_master_death(_master_id, state), do: {:noreply, state}

  @doc """
  Leaves a living mob at exactly 1 HP and 1 SP. The hit is active damage for the
  mob's statuses even when the mob is already at 1 HP.
  """
  @spec handle_coma(tuple() | integer() | nil, map(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_coma(_source, _metadata, %{is_dead: true} = state), do: {:noreply, state}
  def handle_coma(_source, _metadata, %{hp: hp} = state) when hp <= 0, do: {:noreply, state}

  def handle_coma(source, metadata, state) do
    hp_damage = max(state.hp - 1, 0)
    coma = coma_metadata(metadata)

    {:noreply, state} =
      if hp_damage > 0,
        do: handle_apply_damage(hp_damage, source, coma, state),
        else: notify_coma(source, coma, state)

    if state.sp == 1,
      do: {:noreply, state},
      else: {:noreply, StateCommit.commit(%{state | sp: 1})}
  end

  # A coma hit keeps what the mob's statuses and its attacked event need from
  # the prepared hit.
  defp coma_metadata(metadata),
    do:
      metadata
      |> Map.take([
        :damage_broken,
        :walk_delay?,
        :div,
        :weapon_attack?,
        :hit_damage,
        :passive?,
        :blocked?,
        :magic_rod_miss?,
        :connected?,
        :reflected
      ])
      |> Map.put(:coma?, true)

  # A damaging battle hit stops the mob walking unless it endures the hit or is
  # on an escape walk.
  defp maybe_hit_stop(%MobState{} = mob, metadata) do
    if HitStop.stops_walk?(metadata) and not mob.can_escape and
         not Endure.holds?(:mob, mob.instance_id, mob, false),
       do: MovementHandler.handle_hit_stop(mob),
       else: mob
  end

  # A coma hit on a mob already at 1 HP takes nothing but is still active damage.
  defp notify_coma(source, metadata, state) do
    state = CastingHandler.interrupt_on_damage(state, Map.put(metadata, :damage, 0))

    StatusInterpreter.on_damage(
      :mob,
      state.instance_id,
      Map.merge(metadata, %{
        damage: 0,
        element: :neutral,
        hp_after: state.hp,
        max_hp: state.calculated.max_hp,
        attacker: typed_attacker(source)
      })
    )

    AttackedEvent.schedule(state, 0, typed_attacker(source), metadata)
    {:noreply, maybe_hit_stop(state, metadata)}
  end

  @doc """
  Applies passive HP loss that never kills: the loss stops at 1 HP. No aggro,
  AI reaction or attacked event follows, since no attacker hit the mob.
  """
  @spec handle_passive_hp_loss(pos_integer(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_passive_hp_loss(_amount, %{is_dead: true} = state), do: {:noreply, state}

  def handle_passive_hp_loss(amount, %{hp: hp} = state) do
    case min(amount, hp - 1) do
      loss when loss > 0 ->
        {updated_mob, :alive} = MobState.apply_damage(state, loss)
        SpawnView.notify_hp_update(updated_mob)
        {:noreply, StateCommit.commit(updated_mob)}

      _none ->
        {:noreply, state}
    end
  end

  @doc """
  A script kill: the statuses death ends end, the mob leaves the registry and
  its session stops, whose removal ends the remaining statuses. No death event,
  reward or respawn follows.
  """
  @spec handle_script_kill(MobState.t()) :: {:stop, :normal, :ok, MobState.t()}
  def handle_script_kill(state) do
    StatusInterpreter.remove_on_death(:mob, state.instance_id)
    UnitRegistry.unregister_unit(:mob, state.instance_id)
    {:stop, :normal, :ok, state}
  end

  @doc "Applies nonlethal equipment vanish from a max-HP percentage."
  @spec handle_vanish(non_neg_integer(), tuple(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_vanish(_hp_percent, _source, %{is_dead: true} = state), do: {:noreply, state}

  def handle_vanish(hp_percent, source, state) do
    hp_amount = div(state.calculated.max_hp * max(hp_percent, 0), 100)
    hp_damage = min(hp_amount, max(state.hp - 1, 0))

    if hp_damage > 0,
      do: handle_apply_damage(hp_damage, source, %{passive?: true}, state),
      else: {:noreply, state}
  end

  @doc """
  Heals the mob by `amount`, clamped at max HP, and broadcasts the new HP. A
  dead mob, a mob in Frenzy and non-positive amounts are silent no-ops.
  """
  @spec handle_heal(integer(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_heal(_amount, %{is_dead: true} = state), do: {:noreply, state}

  def handle_heal(amount, state) when is_integer(amount) and amount > 0 do
    if DamageApplication.heal_refused?(:mob, state.instance_id) do
      {:noreply, state}
    else
      state = StateCommit.commit(%{state | hp: min(state.hp + amount, state.calculated.max_hp)})
      SpawnView.notify_hp_update(state)
      {:noreply, state}
    end
  end

  def handle_heal(_amount, state), do: {:noreply, state}

  @doc """
  Takes `amount` HP without source, aggro, damage log or kill: applied only
  while the mob is alive and `amount` is below its current HP.
  """
  @spec handle_zap_hp(integer(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_zap_hp(amount, %{is_dead: false, hp: hp} = state)
      when is_integer(amount) and amount > 0 and amount < hp do
    state = StateCommit.commit(%{state | hp: hp - amount})
    SpawnView.notify_hp_update(state)
    {:noreply, state}
  end

  def handle_zap_hp(_amount, state), do: {:noreply, state}

  defp maybe_add_aggro(state, _reward_owner_id, nil, _damage), do: state

  defp maybe_add_aggro(state, reward_owner_id, attacker_ref, damage) do
    state = MobState.add_typed_aggro(state, attacker_ref, reward_owner_id, damage)

    if is_integer(reward_owner_id) do
      MobState.add_aggro(state, reward_owner_id, damage)
    else
      state
    end
  end

  defp reward_owner_id(nil), do: nil
  defp reward_owner_id({:player, attacker_id}), do: attacker_id

  defp reward_owner_id({:homunculus, attacker_id}) do
    case UnitRegistry.get_unit(:homunculus, attacker_id) do
      {:ok, {HomunculusState, %HomunculusState{owner_character_id: owner_id}, _pid}} -> owner_id
      _other -> nil
    end
  end

  defp reward_owner_id({:mob, attacker_id}) do
    case UnitRegistry.get_unit(:mob, attacker_id) do
      {:ok, {MobState, %MobState{owner_player_id: owner_player_id}, _pid}}
      when is_integer(owner_player_id) ->
        owner_player_id

      {:ok, _unit} ->
        nil

      {:error, :not_found} ->
        nil
    end
  end

  defp typed_attacker(nil), do: nil
  defp typed_attacker({_type, _id} = attacker_ref), do: attacker_ref

  defp typed_attacker(attacker_id) when is_integer(attacker_id) do
    cond do
      match?({:ok, _unit}, UnitRegistry.get_unit(:player, attacker_id)) -> {:player, attacker_id}
      match?({:ok, _unit}, UnitRegistry.get_unit(:mob, attacker_id)) -> {:mob, attacker_id}
      true -> {:player, attacker_id}
    end
  end

  defp kill_credit(attacker_ref, reward_owner_id) do
    %{
      attacker: attacker_ref,
      character_id: reward_owner_id,
      guild_id: reward_owner_guild_id(reward_owner_id)
    }
  end

  defp reward_owner_guild_id(nil), do: nil

  defp reward_owner_guild_id(character_id) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {PlayerState, %PlayerState{guild_id: guild_id}, _pid}}
      when is_integer(guild_id) and guild_id > 0 ->
        guild_id

      _other ->
        nil
    end
  end

  @doc """
  Resets the monster into `replacement_id`'s form, keeping everything a class
  change keeps.

  Guardians, the emperium, treasure boxes and player summons never change form,
  and a same-form or unknown replacement is refused. Otherwise the form changes,
  the form's own locks end, attack, walk and cast stop, the new form's base is
  calculated with no held status contribution, HP follows
  `monster_class_change_full_recover`, every skill cooldown and the mob's targets
  are dropped, and the damage history is cleared only on the full-recovery
  branch. Held statuses, the runtime level, looted items, the AI skill state,
  already-fired deferred work and an established attack deadline all survive.
  Exactly one commit publishes the result.
  """
  @spec handle_polymorph(integer(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_polymorph(replacement_id, %MobState{} = state) when is_integer(replacement_id) do
    with {:ok, replacement} <- Mobs.by_id(replacement_id),
         :ok <- form_change_allowed?(state, replacement) do
      hp_rate = hp_percentage(state)

      state = MobState.change_form(state, replacement)
      :ok = end_form_locks(state.instance_id)

      state =
        state
        |> MobState.stop_attack()
        |> stop_walk()
        |> CastingHandler.cancel_cast_for_form_change()

      SpawnView.notify_class_change(state)

      state = state |> reset_form(hp_rate) |> StateCommit.commit()
      SpawnView.notify_hp_update(state)

      {:noreply, state}
    else
      :error -> {:noreply, state}
      {:error, _reason} -> {:noreply, state}
    end
  end

  def handle_polymorph(_replacement_id, %MobState{} = state), do: {:noreply, state}

  defp handle_death(state, attacker_ref, reward_owner_id, kill_blow, kill_credit) do
    exp_bonus = kill_exp_bonus(state.instance_id)
    drops_suppressed? = drops_suppressed?(state)

    # Mark as dead and publish before announcing, so observers reacting to
    # the death already read a dead snapshot.
    updated_state =
      state
      |> MobState.advance_deferred_epoch()
      |> MobState.set_dead()
      |> StateCommit.commit()

    StatusInterpreter.remove_on_death(:mob, state.instance_id)

    # Notify nearby players of mob death
    SpawnView.notify_despawn(updated_state)
    Lifecycle.publish_death(:mob, state.instance_id, state.map_name, kill_credit)

    if drops_suppressed? or not is_integer(reward_owner_id),
      do: Looting.drop_on_death(state)

    announce_kill(state, attacker_ref, reward_owner_id, kill_blow, exp_bonus, drops_suppressed?)
    Slaves.master_died(updated_state)

    # Notify coordinator of death for respawn scheduling and OnMyMobDead dispatch
    Coordinator.mob_died(state.map_name, state.instance_id, reward_owner_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  # Pre-renewal Mr. Kim a Rich Man rides on the killed mob, so its bonus is
  # read here, before the death broadcast lets field cleanup drop the status.
  defp kill_exp_bonus(instance_id) do
    with :pre_renewal <- GameMode.mode(),
         %StatusEntry{val1: level} <-
           StatusStorage.get_status(:mob, instance_id, :sc_richmankim) do
      RichmanKim.kill_exp_bonus(level)
    else
      :renewal -> 0
      nil -> 0
    end
  end

  # Distributes typed EXP to every eligible contributor
  # (`KillExp.distribute_typed/7`), grants the MVP reward for an MVP-tier boss,
  # then sends quest credit and drop rolling to the killing blow's reward-owner
  # session when one exists. A rootless final source still completes shared
  # rewards but has no session to receive kill-local rewards. `exp_bonus` is a
  # percent applied to both rate-scaled amounts before they are shared.
  defp announce_kill(_state, nil, _reward_owner_id, _kill_blow, _exp_bonus, _drops_suppressed?),
    do: :ok

  defp announce_kill(
         %MobState{mob_data: mob_data, aggro_list: aggro_list} = state,
         attacker_ref,
         reward_owner_id,
         kill_blow,
         exp_bonus,
         drops_suppressed?
       ) do
    ownership = LootOwnership.determine_typed(state)

    unless state.no_exp do
      KillExp.distribute_typed(
        MobState.typed_damage_log(state),
        mob_data.base_exp |> apply_rate(Config.base_exp_rate()) |> apply_rate(100 + exp_bonus),
        mob_data.job_exp |> apply_rate(Config.job_exp_rate()) |> apply_rate(100 + exp_bonus),
        mob_data.level,
        state.map_name,
        mob_data.race,
        state
      )
    end

    MvpReward.grant(aggro_list, mob_data, state.map_name, state.x, state.y, ownership)

    if is_integer(reward_owner_id) do
      QuestHuntCredit.credit(reward_owner_id, mob_data.id, state.map_name, {state.x, state.y})
      announce_kill_gain(reward_owner_id, attacker_ref, mob_data, kill_blow)

      unless drops_suppressed? do
        PubSub.broadcast(
          Aesir.PubSub,
          "player:#{reward_owner_id}",
          {:loot,
           {:mob_killed,
            %{
              mob_id: mob_data.id,
              drops: mob_data.drops,
              looted_items: state.looted_items,
              mob_level: mob_data.level,
              mob_race: mob_data.race,
              fixed_item_drop?: :fixed_item_drop in (mob_data.modes || []),
              map: state.map_name,
              x: state.x,
              y: state.y,
              ownership: ownership,
              boss?: MobState.is_boss?(state),
              final_source: attacker_ref
            }}}
        )
      end
    end
  end

  # A dead monster rolls no drops when its own rewards are suppressed (a
  # player summon) or when the map forbids monster loot. Its carried loot is
  # returned to the floor either way, by `Looting.drop_on_death/1`.
  @spec drops_suppressed?(MobState.t()) :: boolean()
  defp drops_suppressed?(%MobState{no_drops: no_drops, map_name: map_name}),
    do: no_drops or MapFlags.get(map_name, :nomobloot)

  # Grants the killer the on-kill HP/SP gain equipment bonuses, decoupled from
  # drops so a no-drop mob still heals its killer. Only weapon/magic blows are
  # gain-eligible; the reader further restricts this to the reward owner's own
  # killing blow (a homunculus/slave kill credits rewards but not on-kill gain).
  defp announce_kill_gain(reward_owner_id, attacker_ref, mob_data, {kill_bf, skill_id})
       when kill_bf in [:melee, :ranged, :magic] do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{reward_owner_id}",
      {:loot,
       {:kill_gain,
        %{
          kill_bf: kill_bf,
          mob_race: mob_data.race,
          final_source: attacker_ref,
          skill_id: skill_id,
          mob_level: mob_data.level
        }}}
    )
  end

  defp announce_kill_gain(_reward_owner_id, _attacker_ref, _mob_data, _kill_blow), do: :ok

  # Scales a mob's undivided reward by a server rate percentage before it is
  # split across attackers. A 0 amount or 0 rate yields 0 (no EXP).
  @spec apply_rate(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  defp apply_rate(amount, 100), do: amount
  defp apply_rate(amount, rate), do: div(amount * rate, 100)

  # The source refuses a class change on castle-owned units (guardians and the
  # emperium), on treasure boxes and on player summons (spheres, floras and the
  # other summoned units whose stats scale from their summoner), and on a
  # replacement that names the monster's current form.
  defp form_change_allowed?(%MobState{} = state, replacement) do
    cond do
      state.mob_id == replacement.id -> {:error, :unchanged_form}
      :treasure in (state.mob_data.race_groups || []) -> {:error, :treasure_box}
      guardian?(state) -> {:error, :guardian}
      is_integer(state.owner_player_id) -> {:error, :player_summon}
      true -> :ok
    end
  end

  defp guardian?(%MobState{guild_id: guild_id, mob_id: mob_id}),
    do: guild_id > 0 or mob_id == @emperium_id

  # A form change ends the new form's own locks before anything else: a form
  # that cannot be held ends here, in the same order the change does, so a
  # monster that acquires one is released before the first calculation.
  defp end_form_locks(instance_id) do
    :ok = StatusInterpreter.remove_status(:mob, instance_id, :sc_keeping)
    :ok = StatusInterpreter.remove_status(:mob, instance_id, :sc_barrier)
  end

  @spec hp_percentage(MobState.t()) :: non_neg_integer()
  defp hp_percentage(%MobState{hp: hp, calculated: %Calculated{max_hp: max_hp}}) when max_hp > 0,
    do: div(hp * 100, max_hp)

  # The new form's base is built from the replacement's database values plus the
  # adjustments a spawn keeps: a slave still inherits its master's base speed.
  @spec reset_form(MobState.t(), non_neg_integer()) :: MobState.t()
  defp reset_form(%MobState{} = state, hp_rate) do
    base = Stats.prepare_base(state, polymorph_base_opts(state))

    %{state | base: base, calculated: base}
    |> restore_resources(base, hp_rate)
    |> MobState.clear_skill_cooldowns()
    |> MobState.set_target(nil)
    |> MobState.clear_attacked()
    |> clear_damage_history()
  end

  defp polymorph_base_opts(%MobState{master_id: master_id, mob_data: mob_data})
       when is_integer(master_id) and master_id > 0,
       do: [master_speed: Coordinator.master_base_speed(master_id, mob_data)]

  defp polymorph_base_opts(%MobState{}), do: []

  # Full recovery leaves the new form at its ceiling; otherwise the new form
  # keeps the pre-change HP percentage, never below 1 HP. The product wraps at
  # 32 bits, as the source's unsigned multiplication does.
  defp restore_resources(%MobState{} = state, base, hp_rate) do
    hp =
      if Config.monster_class_change_full_recover?(),
        do: base.max_hp,
        else: base.max_hp |> Kernel.*(hp_rate) |> Integer.mod(4_294_967_296) |> div(100) |> max(1)

    %{state | hp: hp, sp: base.max_sp}
  end

  defp clear_damage_history(%MobState{} = state) do
    if Config.monster_class_change_full_recover?(), do: MobState.clear_aggro(state), else: state
  end

  # Stops a walk in progress without a position update: the class change's stop
  # carries no fix-position request, so no observer is snapped to the cell and
  # no half-built form is published before the single commit.
  defp stop_walk(%MobState{} = state),
    do: MobState.stop_movement(%{state | chase_target: nil, chase_resume_at: nil})
end
