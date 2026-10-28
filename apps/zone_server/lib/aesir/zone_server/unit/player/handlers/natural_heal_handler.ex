defmodule Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler do
  @moduledoc """
  Drives the per-session natural HP/SP regeneration tick.

  Every tick, dead or alive, it gathers the facts `NaturalHeal` reads (merged
  status modifiers plus the equipment recovery rates, learned regeneration
  passives, the equipment no-regen mask, sitting, walking, overweight, the
  guild castle bonus, death or concealment, and Tension Relax), runs
  `NaturalHeal.plan/1` and `NaturalHeal.tick/4` over the session's
  `regen_timing`, and stores the new timing.

  Only a tick that restores HP or SP commits the game state, pushes the changed
  `SP_HP`/`SP_SP` to the client and persists asynchronously; any other tick
  touches nothing but the session's `regen_timing`.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Concealment
  alias Aesir.ZoneServer.Unit.Inventory.Weight
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal.Inputs
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Runs one natural-heal tick of `elapsed_ms` for the player session.
  """
  @spec handle_tick(SessionState.t(), non_neg_integer()) :: {:noreply, SessionState.t()}
  def handle_tick(%SessionState{game_state: game_state} = state, elapsed_ms) do
    %{stats: stats, character_id: id} = game_state

    inputs = %Inputs{
      stats: stats,
      modifiers: regen_modifiers(game_state),
      passive_regen: Passives.regen(stats),
      sitting_regen: Passives.sitting_regen(stats),
      no_regen_mask: Map.get(stats.modifiers.equipment, :no_regen, 0),
      sitting?: game_state.action_state == :sitting,
      walking?: game_state.movement_state == :moving,
      overweight?: Weight.regen_overweight?(game_state.inventory, stats),
      castle_bonus?: state.castle_regen?,
      blocked?: game_state.action_state == :dead or Concealment.unit_concealed?(:player, id),
      tension_relax?: StatusStorage.has_status?(:player, id, :sc_tensionrelax)
    }

    vitals = %{
      hp: stats.current_state.hp,
      sp: stats.current_state.sp,
      max_hp: stats.derived_stats.max_hp,
      max_sp: stats.derived_stats.max_sp
    }

    {hp_delta, sp_delta, timing} =
      inputs
      |> NaturalHeal.plan()
      |> NaturalHeal.tick(state.regen_timing, elapsed_ms, vitals)

    {:noreply, apply_regen(%{state | regen_timing: timing}, hp_delta, sp_delta)}
  end

  # The equipment recovery rates add to the statuses' `hp_regen`/`sp_regen`.
  defp regen_modifiers(game_state) do
    status_modifiers = ModifierCalculator.get_all_modifiers(:player, game_state.character_id)
    equipment = game_state.stats.modifiers.equipment

    Enum.reduce([:hp_regen, :sp_regen], status_modifiers, fn key, acc ->
      case Map.get(equipment, key, 0) do
        0 -> acc
        bonus -> Map.update(acc, key, bonus, &(&1 + bonus))
      end
    end)
  end

  defp apply_regen(state, 0, 0), do: state

  defp apply_regen(%SessionState{game_state: game_state} = state, hp_delta, sp_delta) do
    %{stats: stats} = game_state
    new_hp = stats.current_state.hp + hp_delta
    new_sp = stats.current_state.sp + sp_delta
    stats = %{stats | current_state: %{stats.current_state | hp: new_hp, sp: new_sp}}
    state = StateCommit.commit(state, %{game_state | stats: stats})

    if hp_delta > 0, do: StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    if sp_delta > 0, do: StatusSync.send_param(state.connection_pid, StatusParams.sp(), new_sp)

    changed =
      %{}
      |> put_when(hp_delta > 0, :hp, new_hp)
      |> put_when(sp_delta > 0, :sp, new_sp)

    CharacterPersistence.update_stats(game_state.character_id, changed, async: true)
    state
  end

  defp put_when(map, true, key, value), do: Map.put(map, key, value)
  defp put_when(map, false, _key, _value), do: map
end
