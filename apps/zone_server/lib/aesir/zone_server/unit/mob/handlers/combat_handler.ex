defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler do
  @moduledoc """
  Handles a mob's combat orchestration: damage application, aggro/rude-attack
  bookkeeping, and the death/kill-announcement pipeline. Extracted from
  MobSession to improve modularity and maintainability.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MvpReward
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
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
  def handle_apply_damage(_damage, _attacker_id, %{is_dead: true} = state) do
    {:noreply, state}
  end

  def handle_apply_damage(damage, attacker, state) do
    {updated_mob, status} = MobState.apply_damage(state, damage)
    current_time = System.system_time(:second)
    attacker_ref = typed_attacker(attacker)
    reward_owner_id = reward_owner_id(attacker_ref)

    updated_mob =
      updated_mob
      |> Map.put(:last_damage_time, current_time)
      |> maybe_add_aggro(reward_owner_id, attacker_ref, damage)
      |> AIStateMachine.handle_damage_reaction(attacker_ref)
      |> maybe_note_rude_attack(attacker_ref)

    # Send HP update packet to nearby players
    SpawnView.notify_hp_update(updated_mob)

    case status do
      :alive ->
        {:noreply, updated_mob}

      :dead ->
        handle_death(
          updated_mob,
          attacker_ref,
          reward_owner_id,
          MobState.hit_type(state, attacker)
        )
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

  defp handle_death(state, attacker_ref, reward_owner_id, kill_bf) do
    # Mark as dead
    updated_state = state |> MobState.advance_deferred_epoch() |> MobState.set_dead()

    # Notify nearby players of mob death
    SpawnView.notify_despawn(updated_state)
    Lifecycle.publish_death(:mob, state.instance_id, state.map_name)

    announce_kill(state, attacker_ref, reward_owner_id, kill_bf)

    # Notify coordinator of death for respawn scheduling and OnMyMobDead dispatch
    Coordinator.mob_died(state.map_name, state.instance_id, reward_owner_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  # Distributes typed EXP to every eligible contributor
  # (`KillExp.distribute_typed/7`), grants the MVP reward for an MVP-tier boss,
  # then sends quest credit and drop rolling to the killing blow's reward-owner
  # session when one exists. A rootless final source still completes shared
  # rewards but has no session to receive kill-local rewards.
  defp announce_kill(_state, nil, _reward_owner_id, _kill_bf), do: :ok

  defp announce_kill(
         %MobState{mob_data: mob_data, aggro_list: aggro_list} = state,
         attacker_ref,
         reward_owner_id,
         kill_bf
       ) do
    ownership = LootOwnership.determine_typed(state)

    unless state.no_exp do
      KillExp.distribute_typed(
        MobState.typed_damage_log(state),
        mob_data.base_exp,
        mob_data.job_exp,
        mob_data.level,
        state.map_name,
        mob_data.race,
        state
      )
    end

    MvpReward.grant(aggro_list, mob_data, state.map_name, state.x, state.y, ownership)

    if is_integer(reward_owner_id) do
      QuestHuntCredit.credit(reward_owner_id, mob_data.id, state.map_name, {state.x, state.y})
      announce_kill_gain(reward_owner_id, attacker_ref, mob_data.race, kill_bf)

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
  defp announce_kill_gain(reward_owner_id, attacker_ref, mob_race, kill_bf)
       when kill_bf in [:melee, :ranged, :magic] do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{reward_owner_id}",
      {:loot, {:kill_gain, %{kill_bf: kill_bf, mob_race: mob_race, final_source: attacker_ref}}}
    )
  end

  defp announce_kill_gain(_reward_owner_id, _attacker_ref, _mob_race, _kill_bf), do: :ok
end
