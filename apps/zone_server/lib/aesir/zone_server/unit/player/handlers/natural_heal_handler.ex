defmodule Aesir.ZoneServer.Unit.Player.Handlers.NaturalHealHandler do
  @moduledoc """
  Drives the per-session natural HP/SP regeneration tick.

  On each tick it gathers the inputs the pure `NaturalHeal` module needs — the
  player's stats and action/movement state, the aggregated regen modifiers
  (`hp_regen`/`sp_regen`, statuses plus equipment), and the passive regen
  contribution from learned skills — applies the resulting clamped deltas to current HP/SP, carries
  the updated accumulators back onto the player state, and (only when a delta is
  non-zero) pushes `SP_HP`/`SP_SP` to the client and persists asynchronously.

  Ticks are skipped entirely when the player is dead or already at full HP and
  full SP, so an idle full-health player produces no packets or DB writes.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Computes and applies one natural-heal tick for the player session.

  `elapsed_ms` is the time since the previous tick (the session's tick interval).
  Returns `{:noreply, state}`. A no-op (returning the state unchanged) when the
  player is dead or already at full HP and SP.
  """
  @spec handle_tick(map(), non_neg_integer()) :: {:noreply, map()}
  def handle_tick(%{game_state: %{action_state: :dead}} = state, _elapsed_ms),
    do: {:noreply, state}

  def handle_tick(%{game_state: game_state} = state, elapsed_ms) do
    stats = game_state.stats

    if full?(stats) do
      {:noreply, state}
    else
      regen_modifiers = regen_modifiers(game_state)
      passive_regen = Passives.regen(game_state)

      accumulators = Map.put(game_state.regen_accumulators, :elapsed_ms, elapsed_ms)

      {hp_delta, sp_delta, accumulators} =
        NaturalHeal.compute(
          stats,
          game_state.action_state,
          game_state.movement_state,
          regen_modifiers,
          passive_regen,
          accumulators
        )

      new_hp = min(stats.derived_stats.max_hp, stats.current_state.hp + hp_delta)
      new_sp = min(stats.derived_stats.max_sp, stats.current_state.sp + sp_delta)

      updated_stats = %{stats | current_state: %{stats.current_state | hp: new_hp, sp: new_sp}}

      game_state = %{
        game_state
        | stats: updated_stats,
          regen_accumulators: Map.delete(accumulators, :elapsed_ms)
      }

      state = StatsManager.update_game_state(state, game_state)

      apply_regen(state, hp_delta, sp_delta, new_hp, new_sp)

      {:noreply, state}
    end
  end

  # Regen percentages come from two independent sources that add: the caster's
  # active statuses and the equipped items' `hp_regen`/`sp_regen` bonuses.
  @spec regen_modifiers(map()) :: NaturalHeal.regen_modifiers()
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

  defp apply_regen(_state, 0, 0, _new_hp, _new_sp), do: :ok

  defp apply_regen(state, hp_delta, sp_delta, new_hp, new_sp) do
    if hp_delta > 0 do
      StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    end

    if sp_delta > 0 do
      StatusSync.send_param(state.connection_pid, StatusParams.sp(), new_sp)
    end

    changed =
      %{}
      |> put_when(hp_delta > 0, :hp, new_hp)
      |> put_when(sp_delta > 0, :sp, new_sp)

    CharacterPersistence.update_stats(state.game_state.character_id, changed, async: true)
  end

  defp put_when(map, true, key, value), do: Map.put(map, key, value)
  defp put_when(map, false, _key, _value), do: map

  defp full?(stats) do
    stats.current_state.hp >= stats.derived_stats.max_hp and
      stats.current_state.sp >= stats.derived_stats.max_sp
  end
end
