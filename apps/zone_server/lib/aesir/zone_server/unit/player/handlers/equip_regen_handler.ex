defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler do
  @moduledoc """
  Drives the per-session periodic HP/SP regen/loss granted by equipment
  (`bHPRegenRate`/`bHPLossRate`/`bSPRegenRate`/`bSPLossRate`), sharing the
  natural-heal tick cadence.

  Unlike natural regen this runs even at full HP/SP, because a periodic HP-loss
  item must still bleed the wearer, and it applies loss before regen: HP loss
  cannot kill (the wearer is floored at 1 HP), SP loss floors at 0, and regen
  cannot exceed the maxima, matching the tick order of the natural-heal loop.
  When the wearer carries no such gear the tick is a no-op producing no state
  commit, packet, or DB write.

  A dead player is skipped entirely.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Unit.Player.EquipRegen
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatsManager
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @doc """
  Computes and applies one periodic equipment HP/SP regen/loss tick.

  `elapsed_ms` is the time since the previous tick. Returns `{:noreply, state}`,
  unchanged when the player is dead or wears no periodic regen/loss gear.
  """
  @spec handle_tick(map(), non_neg_integer()) :: {:noreply, map()}
  def handle_tick(%{game_state: %{action_state: :dead}} = state, _elapsed_ms),
    do: {:noreply, state}

  def handle_tick(%{game_state: game_state} = state, elapsed_ms) do
    stats = game_state.stats

    {deltas, accumulators} =
      EquipRegen.compute(
        stats.modifiers.equipment,
        game_state.equip_regen_accumulators,
        elapsed_ms
      )

    if accumulators == %{} do
      {:noreply, state}
    else
      current = stats.current_state
      derived = stats.derived_stats
      new_hp = min(derived.max_hp, max(current.hp - deltas.hp_loss, 1) + deltas.hp_gain)
      new_sp = min(derived.max_sp, max(current.sp - deltas.sp_loss, 0) + deltas.sp_gain)

      updated_stats = %{stats | current_state: %{current | hp: new_hp, sp: new_sp}}

      game_state = %{
        game_state
        | stats: updated_stats,
          equip_regen_accumulators: accumulators
      }

      state = StatsManager.update_game_state(state, game_state)
      apply_changes(state, current.hp, new_hp, current.sp, new_sp)

      {:noreply, state}
    end
  end

  defp apply_changes(state, old_hp, new_hp, old_sp, new_sp) do
    changed =
      %{}
      |> push_param(state, StatusParams.hp(), old_hp, new_hp, :hp)
      |> push_param(state, StatusParams.sp(), old_sp, new_sp, :sp)

    if changed != %{} do
      CharacterPersistence.update_stats(state.game_state.character_id, changed, async: true)
    end

    :ok
  end

  defp push_param(changed, _state, _param, value, value, _key), do: changed

  defp push_param(changed, state, param, _old, new, key) do
    StatusSync.send_param(state.connection_pid, param, new)
    Map.put(changed, key, new)
  end
end
