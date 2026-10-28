defmodule Aesir.ZoneServer.Unit.Player.Handlers.EquipRegenHandler do
  @moduledoc """
  Drives the per-session periodic HP/SP regen/loss granted by equipment
  (`bHPRegenRate`/`bHPLossRate`/`bSPRegenRate`/`bSPLossRate`), sharing the
  natural-heal tick cadence.

  Unlike natural regen this runs even at full HP/SP, because a periodic HP-loss
  item must still bleed the wearer, and it applies loss before regen: HP loss
  cannot kill (the wearer is floored at 1 HP), SP loss floors at 0, and regen
  cannot exceed the maxima, matching the tick order of the natural-heal loop.
  No-Recover does not stop it; Berserk stops the HP gain only.

  Every stat recalculation (a new `Stats.generation`) restarts the intervals.
  While dead the regen intervals keep running with their gains discarded and
  the loss intervals hold. When the wearer carries no such gear the tick
  produces no state commit, packet, or DB write.
  """

  alias Aesir.Commons.StatusParams
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.EquipRegen
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.StatusSync

  @loss_families [:hp_loss_bonus, :sp_loss_bonus]

  @doc """
  Computes and applies one periodic equipment HP/SP regen/loss tick of
  `elapsed_ms`.
  """
  @spec handle_tick(SessionState.t(), non_neg_integer()) :: {:noreply, SessionState.t()}
  def handle_tick(%SessionState{game_state: game_state} = state, elapsed_ms) do
    stats = game_state.stats

    carried =
      if state.equip_regen_generation == stats.generation,
        do: game_state.equip_regen_accumulators,
        else: %{}

    state = %{state | equip_regen_generation: stats.generation}

    {deltas, accumulators} =
      EquipRegen.compute(stats.modifiers.equipment, carried, elapsed_ms)

    cond do
      accumulators == %{} ->
        {:noreply, state}

      game_state.action_state == :dead ->
        accumulators = hold_losses(accumulators, carried)

        if accumulators == game_state.equip_regen_accumulators,
          do: {:noreply, state},
          else: {:noreply, commit(state, game_state.stats, accumulators)}

      true ->
        current = stats.current_state
        derived = stats.derived_stats
        hp_gain = if berserk?(game_state), do: 0, else: deltas.hp_gain
        new_hp = min(derived.max_hp, max(current.hp - deltas.hp_loss, 1) + hp_gain)
        new_sp = min(derived.max_sp, max(current.sp - deltas.sp_loss, 0) + deltas.sp_gain)

        updated_stats = %{stats | current_state: %{current | hp: new_hp, sp: new_sp}}
        state = commit(state, updated_stats, accumulators)
        apply_changes(state, current.hp, new_hp, current.sp, new_sp)

        {:noreply, state}
    end
  end

  defp commit(state, stats, accumulators) do
    game_state = %{state.game_state | stats: stats, equip_regen_accumulators: accumulators}
    StateCommit.commit(state, game_state)
  end

  defp hold_losses(accumulators, carried) do
    Map.new(accumulators, fn
      {{family, _interval} = key, _acc} when family in @loss_families ->
        {key, Map.get(carried, key, 0)}

      entry ->
        entry
    end)
  end

  defp berserk?(game_state),
    do: StatusStorage.has_status?(:player, game_state.character_id, :sc_berserk)

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
