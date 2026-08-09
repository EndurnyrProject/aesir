defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler do
  @moduledoc """
  Drives the per-session periodic HP regen/loss granted by equipment
  (`bHPRegenRate`/`bHPLossRate`), sharing the natural-heal tick cadence.

  Unlike natural regen this runs even at full HP, because a periodic HP-loss
  item must still bleed the wearer, and it applies loss before regen: loss
  cannot kill (the wearer is floored at 1 HP) and regen cannot exceed max HP,
  matching the tick order of the natural-heal loop. When the wearer carries no
  such gear the tick is a no-op producing no state commit, packet, or DB write.

  A dead player is skipped entirely.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Player.EquipRegen
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Computes and applies one periodic equipment HP regen/loss tick.

  `elapsed_ms` is the time since the previous tick. Returns `{:noreply, state}`,
  unchanged when the player is dead or wears no periodic HP-regen/loss gear.
  """
  @spec handle_tick(map(), non_neg_integer()) :: {:noreply, map()}
  def handle_tick(%{game_state: %{action_state: :dead}} = state, _elapsed_ms),
    do: {:noreply, state}

  def handle_tick(%{game_state: game_state} = state, elapsed_ms) do
    stats = game_state.stats

    {gain, loss, accumulators} =
      EquipRegen.compute(
        stats.modifiers.equipment,
        game_state.equip_regen_accumulators,
        elapsed_ms
      )

    if accumulators == %{} do
      {:noreply, state}
    else
      current_hp = stats.current_state.hp
      max_hp = stats.derived_stats.max_hp
      new_hp = min(max_hp, max(current_hp - loss, 1) + gain)

      updated_stats = %{stats | current_state: %{stats.current_state | hp: new_hp}}

      game_state = %{
        game_state
        | stats: updated_stats,
          equip_regen_accumulators: accumulators
      }

      state = StatsManager.update_game_state(state, game_state)
      apply_hp_change(state, current_hp, new_hp)

      {:noreply, state}
    end
  end

  defp apply_hp_change(_state, hp, hp), do: :ok

  defp apply_hp_change(state, _old_hp, new_hp) do
    StatusSync.send_param(state.connection_pid, StatusParams.hp(), new_hp)
    CharacterPersistence.update_stats(state.game_state.character_id, %{hp: new_hp}, async: true)
  end
end
