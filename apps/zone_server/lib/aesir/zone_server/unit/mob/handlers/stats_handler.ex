defmodule Aesir.ZoneServer.Unit.Mob.Handlers.StatsHandler do
  @moduledoc """
  Owner-side reconciliation of a monster's calculated status snapshot.

  A committed status event is resolved to canonical calculation flags, the
  selected fields are recomputed once from the raw base and the entries held at
  that moment, the source consequences follow, and exactly one commit publishes
  the result. The raw seed changes only through `replace_base/3`, which is a
  normal recalculation of an explicit selection and publishes nothing itself.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.Calculated
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Mob.StateCommit
  alias Aesir.ZoneServer.Unit.Mob.Stats
  alias Aesir.ZoneServer.Unit.Movement

  @slave_modes [:can_move, :no_random_walk, :can_attack]

  @doc """
  Reconciles the calculated snapshot after one committed status event.

  The event's canonical flags select the fields a normal calculation refreshes.
  An empty selection on an apply, removal or armed transition leaves the state
  untouched; a generic tick or expiry is not a calculated event at all. A dead
  monster drops the event.
  """
  @spec handle_status_changed(atom(), atom(), MobState.t()) :: {:noreply, MobState.t()}
  def handle_status_changed(_status_id, event, %MobState{} = state)
      when event not in [:apply, :removed, :armed],
      do: {:noreply, state}

  def handle_status_changed(status_id, event, %MobState{} = state) do
    if MobState.living?(state) do
      reconcile(status_id, event, stop_attacking(status_id, event, state))
    else
      {:noreply, state}
    end
  end

  # A stop-attacking status drops the standing attack order when it starts.
  defp stop_attacking(status_id, :apply, %MobState{attack_target: target} = state)
       when not is_nil(target) do
    if Interpreter.stops_attacking?(status_id),
      do: state |> MobState.stop_attack() |> StateCommit.commit(),
      else: state
  end

  defp stop_attacking(_status_id, _event, state), do: state

  defp reconcile(status_id, event, %MobState{} = state) do
    case CalcFlags.for_event(status_id, event) do
      [] ->
        {:noreply, state}

      flags ->
        committed = state |> recalculate(flags) |> StateCommit.commit()

        if committed.calculated.max_hp != state.calculated.max_hp or committed.hp != state.hp,
          do: SpawnView.notify_hp_update(committed)

        {:noreply, committed}
    end
  end

  @doc """
  Replaces the raw base seed inside an existing owner execution chain.

  `flags` is the source selection the caller owns: NPC Speed Up selects Speed
  alone, a full base rebuild selects All. The selected fields recalculate
  normally from the new seed and the already held entries, so unselected
  retained contributions are not restored. Nothing is published here; the
  owning call chain commits once.
  """
  @spec replace_base(MobState.t(), Calculated.t(), [CalcFlags.flag()]) :: MobState.t()
  def replace_base(%MobState{} = state, %Calculated{} = base, flags) do
    %{state | base: base}
    |> recalculate(flags)
  end

  @doc """
  Applies the source's post-spawn slave mode selection.

  A slave's first calculation keeps its raw form mode; this writes the held
  `SC_MODECHANGE` entry the source's `status_calc_slave_mode` starts, and the
  owner's own `:sc_modechange` event recalculates the derived mode. A mask
  equal to the raw base mode needs no entry, since the source's start rejects
  an unchanged mode.
  """
  @spec initialize_slave_mode(MobState.t()) :: :ok
  def initialize_slave_mode(
        %MobState{master_id: master_id, base: %Calculated{mode: mode}} = state
      )
      when is_integer(master_id) and master_id > 0 do
    mask = MobMode.mask(@slave_modes)

    if mask != mode do
      _ = Interpreter.apply_status(:mob, state.instance_id, :sc_modechange, val1: 1, val2: mask)
    end

    :ok
  end

  def initialize_slave_mode(%MobState{}), do: :ok

  defp recalculate(%MobState{} = state, flags) do
    expanded = Mechanics.mob_formulas().expand_calc_flags(flags)
    selected = MapSet.new(expanded)
    entries = StatusStorage.get_unit_statuses(:mob, state.instance_id)
    calculated = Stats.recalculate(state, entries, expanded)

    state = %{state | calculated: calculated}
    state = if MapSet.member?(selected, "Speed"), do: apply_speed(state), else: state
    state = if MapSet.member?(selected, "Mode"), do: apply_mode(state), else: state

    state =
      if MapSet.member?(selected, "MaxHp"),
        do: clamp_resource(state, calculated.max_hp, :hp),
        else: state

    if MapSet.member?(selected, "MaxSp"),
      do: clamp_resource(state, calculated.max_sp, :sp),
      else: state
  end

  # The source re-walks on a speed selection so the new speed prices the steps
  # after the pending one, which keeps its own token, cost and deadline. The
  # speed itself already lives in the recalculated snapshot.
  defp apply_speed(state), do: MovementHandler.rewalk_after_speed_change(state)

  defp clamp_resource(state, maximum, current_field) do
    Map.update!(state, current_field, &min(&1, maximum))
  end

  # A mode selection that drops attack or movement stops the mob, never its cast.
  # The source's stop-walking returns before its fix-position broadcast unless a
  # walk is actually in progress, so a standing mob is left alone.
  defp apply_mode(state) do
    modes = MobMode.from_mask(state.calculated.mode)
    state = if :can_attack in modes, do: state, else: MobState.stop_attack(state)

    if :can_move in modes or state.movement_state != :moving do
      state
    else
      stopped = MobState.stop_movement(state)
      Movement.set_position(:mob, stopped.instance_id, stopped, stopped.map_name)
      stopped
    end
  end
end
