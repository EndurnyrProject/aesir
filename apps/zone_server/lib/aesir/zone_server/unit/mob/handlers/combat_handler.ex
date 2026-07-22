defmodule Aesir.ZoneServer.Unit.Mob.Handlers.CombatHandler do
  @moduledoc """
  Handles a mob's combat orchestration: damage application, aggro/rude-attack
  bookkeeping, and the death/kill-announcement pipeline. Extracted from
  MobSession to improve modularity and maintainability.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Unit.Lifecycle
  alias Aesir.ZoneServer.Unit.Mob.AIStateMachine
  alias Aesir.ZoneServer.Unit.Mob.KillExp
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.MvpReward
  alias Aesir.ZoneServer.Unit.Mob.QuestHuntCredit
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.SpatialIndex
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
  @spec handle_apply_damage(integer(), integer() | nil, MobState.t()) :: {:noreply, MobState.t()}
  def handle_apply_damage(_damage, _attacker_id, %{is_dead: true} = state) do
    {:noreply, state}
  end

  def handle_apply_damage(damage, attacker_id, state) do
    {updated_mob, status} = MobState.apply_damage(state, damage)
    current_time = System.system_time(:second)

    # Update last damage time and add aggro if attacker provided
    updated_mob =
      updated_mob
      |> Map.put(:last_damage_time, current_time)
      |> maybe_add_aggro(attacker_id, damage)
      |> AIStateMachine.handle_damage_reaction(attacker_id)
      |> maybe_note_rude_attack(attacker_id)

    # Send HP update packet to nearby players
    SpawnView.notify_hp_update(updated_mob)

    case status do
      :alive ->
        {:noreply, updated_mob}

      :dead ->
        handle_death(updated_mob, attacker_id)
    end
  end

  defp maybe_add_aggro(state, nil, _damage), do: state

  defp maybe_add_aggro(state, attacker_id, damage) do
    MobState.add_aggro(state, attacker_id, damage)
  end

  # Records a rude attack when the hit came from beyond the mob's chase range
  # (an attacker it cannot path to). Phase 1 only counts the signal; Phase 2's
  # `rudeattacked` condition consumes it. An attacker whose position can't be
  # resolved is skipped silently.
  defp maybe_note_rude_attack(state, attacker_id) when is_integer(attacker_id) do
    case resolve_attacker_position(attacker_id) do
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

  # The attacker type isn't known here, so try :player then :mob (mirrors the
  # combat action handler's target resolution).
  defp resolve_attacker_position(attacker_id) do
    case SpatialIndex.get_unit_position(:player, attacker_id) do
      {:ok, {x, y, _map}} ->
        {:ok, {x, y}}

      {:error, :not_found} ->
        case SpatialIndex.get_unit_position(:mob, attacker_id) do
          {:ok, {x, y, _map}} -> {:ok, {x, y}}
          {:error, :not_found} -> :error
        end
    end
  end

  defp handle_death(state, attacker_id) do
    # Mark as dead
    updated_state = MobState.set_dead(state)

    # Notify nearby players of mob death
    SpawnView.notify_despawn(updated_state)
    Lifecycle.publish_death(:mob, state.instance_id, state.map_name)

    announce_kill(state, attacker_id)

    # Notify coordinator of death for respawn scheduling and OnMyMobDead dispatch
    Coordinator.mob_died(state.map_name, state.instance_id, attacker_id)

    # Schedule process termination after a brief delay to handle cleanup
    Process.send_after(self(), :terminate, 1000)

    {:noreply, updated_state}
  end

  # Distributes EXP to every attacker who damaged the mob, proportional to
  # damage dealt (`KillExp.distribute/6`, design "Damage-based EXP share"),
  # grants the MVP reward for an MVP-tier boss (`MvpReward.grant/5`, a no-op
  # for every other mob), then publishes the drop-rolling payload to the
  # killing blow's own session
  # (the only place holding both the drop table and the killer's stats). The
  # mob stays ignorant of who listens; an absent killer simply has no
  # subscriber.
  defp announce_kill(_state, nil), do: :ok

  defp announce_kill(%MobState{mob_data: mob_data, aggro_list: aggro_list} = state, attacker_id) do
    KillExp.distribute(
      aggro_list,
      mob_data.base_exp,
      mob_data.job_exp,
      mob_data.level,
      state.map_name,
      mob_data.race
    )

    MvpReward.grant(aggro_list, mob_data, state.map_name, state.x, state.y)

    QuestHuntCredit.credit(attacker_id, mob_data.id, state.map_name, {state.x, state.y})

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{attacker_id}",
      {:loot,
       {:mob_killed,
        %{
          mob_id: mob_data.id,
          drops: mob_data.drops,
          mob_level: mob_data.level,
          map: state.map_name,
          x: state.x,
          y: state.y
        }}}
    )
  end
end
