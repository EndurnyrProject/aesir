defmodule Aesir.ZoneServer.Unit.Mob.SessionAdapter do
  @moduledoc """
  `Unit.Session.Adapter` for mobs.

  Operates on the `MobState` directly (a mob session's state is its `MobState`).
  Mob vitals are the plain `hp`/`sp`/`max_hp`/`max_sp` fields; HP changes reach
  nearby clients as a `UnitHp` broadcast via `Mob.SpawnView`, and the registry
  snapshot is refreshed through `UnitRegistry.update_unit_state/3`.

  Note: the current mob heal/SP-drain paths do not touch the unit registry, so
  `commit/2` here is a capability the shared vitals handler may or may not invoke
  for mobs — the routing task owns that policy, this adapter only exposes it.
  """

  @behaviour Aesir.ZoneServer.Unit.Session.Adapter

  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Mob.SpawnView
  alias Aesir.ZoneServer.Unit.Movement
  alias Aesir.ZoneServer.Unit.Session.Adapter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl Adapter
  @spec get_vitals(MobState.t()) :: Adapter.vitals()
  def get_vitals(%MobState{hp: hp, sp: sp, max_hp: max_hp, max_sp: max_sp}) do
    %{hp: hp, sp: sp, max_hp: max_hp, max_sp: max_sp}
  end

  @impl Adapter
  @spec put_vitals(MobState.t(), Adapter.vitals_update()) :: MobState.t()
  def put_vitals(%MobState{} = state, updates) do
    %{state | hp: Map.get(updates, :hp, state.hp), sp: Map.get(updates, :sp, state.sp)}
  end

  @impl Adapter
  @spec notify_vitals(MobState.t()) :: :ok
  def notify_vitals(%MobState{} = state) do
    SpawnView.notify_hp_update(state)
    :ok
  end

  @impl Adapter
  @spec set_position(MobState.t(), Adapter.position()) :: MobState.t()
  def set_position(%MobState{} = state, {x, y}) do
    state = MobState.update_position(state, x, y)
    Movement.set_position(:mob, state.instance_id, state, state.map_name)
    state
  end

  @impl Adapter
  @spec stop_movement(MobState.t()) :: MobState.t()
  def stop_movement(%MobState{} = state) do
    MobState.stop_movement(state)
  end

  @impl Adapter
  @spec commit(MobState.t(), MobState.t()) :: MobState.t()
  def commit(%MobState{}, %MobState{} = updated) do
    UnitRegistry.update_unit_state(:mob, updated.instance_id, updated)
    updated
  end
end
