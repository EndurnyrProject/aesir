defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler do
  @moduledoc """
  Handles a mob's combat orchestration: damage application, aggro/rude-attack
  bookkeeping, and the death/kill-announcement pipeline. Extracted from
  MobSession to improve modularity and maintainability.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.RichmanKim
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry, as: StatusRegistry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.Handlers.CastingHandler
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MvpReward
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Mob.StateCommit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @doc """
  Applies `damage` to the mob, from `attacker_id` if known.

  A dead mob is no longer a valid target: dropping the hit (the first clause)
  prevents re-running the death path (and re-awarding experience) during the
  ~1s window between death and process termination, while it is still in the
  registry/index. A live mob gets aggro/rude-attack bookkeeping, an AI
  reaction to the hit, and an HP broadcast to nearby players, then falls
  through to the death path if the hit was lethal.
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
        updated_mob
        |> Map.put(:last_damage_time, current_time)
        |> AIStateMachine.handle_damage_reaction(attacker_ref)
        |> maybe_note_rude_attack(attacker_ref)
      end

    StatusInterpreter.on_damage(
      :mob,
      state.instance_id,
      metadata
      |> Map.put_new(:element, :neutral)
      |> Map.merge(%{
        damage: min(damage, state.hp),
        hp_after: updated_mob.hp,
        max_hp: state.max_hp,
        attacker: attacker_ref
      })
    )

    # Send HP update packet to nearby players
    SpawnView.notify_hp_update(updated_mob)

    case status do
      :alive ->
        {:noreply, StateCommit.commit(updated_mob)}

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

  # A coma hit keeps only what the mob's statuses need from the prepared hit.
  defp coma_metadata(metadata),
    do: metadata |> Map.take([:damage_broken]) |> Map.put(:coma?, true)

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
        max_hp: state.max_hp,
        attacker: typed_attacker(source)
      })
    )

    {:noreply, state}
  end

  @doc """
  Applies passive HP loss that never kills: the loss stops at 1 HP. No aggro,
  AI reaction or rude-attack bookkeeping follows, since no attacker hit the mob.
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

  @doc "Applies nonlethal equipment vanish from a max-HP percentage."
  @spec handle_vanish(non_neg_integer(), tuple(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_vanish(_hp_percent, _source, %{is_dead: true} = state), do: {:noreply, state}

  def handle_vanish(hp_percent, source, state) do
    hp_amount = div(state.max_hp * max(hp_percent, 0), 100)
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
      state = StateCommit.commit(%{state | hp: min(state.hp + amount, state.max_hp)})
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

  @doc """
  Recomputes the HP ceiling after a `:max_hp_rate` status (SC_DELUGE and kin)
  is applied or removed, publishing and broadcasting only when it moved.
  Ordinary status ticks are gated out by the status's `calc_flags`.
  """
  @spec handle_max_hp_status(atom(), MobState.t()) :: MobState.t()
  def handle_max_hp_status(status_id, state) do
    if max_hp_status?(status_id) do
      updated = state |> MobState.recalculate_max_hp() |> StateCommit.commit()
      unless updated.max_hp == state.max_hp, do: SpawnView.notify_hp_update(updated)
      updated
    else
      state
    end
  end

  defp max_hp_status?(status_id) do
    case StatusRegistry.get_definition(status_id) do
      %{calc_flags: flags} -> :max_hp_rate in flags
      _ -> false
    end
  end

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

  # Records a rude attack when the hit came from beyond the mob's chase range
  # (an attacker it cannot path to). Phase 1 only counts the signal; Phase 2's
  # `rudeattacked` condition consumes it. An attacker whose position can't be
  # resolved is skipped silently.
  defp maybe_note_rude_attack(state, {_type, _id} = attacker_ref) do
    case resolve_attacker_position(attacker_ref) do
      {:ok, {x, y}} ->
        if Geometry.chebyshev_distance(x, y, state.x, state.y) >
             MobState.get_chase_range(state) do
          MobState.note_rude_attack(state)
        else
          state
        end

      :error ->
        state
    end
  end

  defp maybe_note_rude_attack(state, _attacker_id), do: state

  defp resolve_attacker_position({type, attacker_id}) do
    case SpatialIndex.get_unit_position(type, attacker_id) do
      {:ok, {x, y, _map}} -> {:ok, {x, y}}
      {:error, :not_found} -> :error
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

  defp handle_death(state, attacker_ref, reward_owner_id, kill_blow, kill_credit) do
    exp_bonus = kill_exp_bonus(state.instance_id)

    # Mark as dead and publish before announcing, so observers reacting to
    # the death already read a dead snapshot.
    updated_state =
      state
      |> MobState.advance_deferred_epoch()
      |> MobState.set_dead()
      |> StateCommit.commit()

    # Notify nearby players of mob death
    SpawnView.notify_despawn(updated_state)
    Lifecycle.publish_death(:mob, state.instance_id, state.map_name, kill_credit)

    announce_kill(state, attacker_ref, reward_owner_id, kill_blow, exp_bonus)

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
  defp announce_kill(_state, nil, _reward_owner_id, _kill_blow, _exp_bonus), do: :ok

  defp announce_kill(
         %MobState{mob_data: mob_data, aggro_list: aggro_list} = state,
         attacker_ref,
         reward_owner_id,
         kill_blow,
         exp_bonus
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

      unless state.no_drops do
        PubSub.broadcast(
          Aesir.PubSub,
          "player:#{reward_owner_id}",
          {:loot,
           {:mob_killed,
            %{
              mob_id: mob_data.id,
              drops: mob_data.drops,
              mob_level: mob_data.level,
              mob_race: mob_data.race,
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
end
