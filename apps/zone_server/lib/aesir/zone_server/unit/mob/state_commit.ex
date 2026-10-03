defmodule Aesir.ZoneServer.Unit.Mob.StateCommit do
  @moduledoc """
  Publishes an authoritative mob-state commit to the unit registry.

  Movement already publishes through `Unit.Movement.set_position/4`; every
  other mutation other units observe (HP, SP, max HP, death) must go through
  here, since combat targeting, AoI snapshots and owner counts read the
  registry snapshot rather than messaging the mob.
  """

  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Writes `state` to the unit registry and returns it unchanged."
  @spec commit(MobState.t()) :: MobState.t()
  def commit(%MobState{instance_id: instance_id} = state) do
    _ = UnitRegistry.update_unit_state(:mob, instance_id, state)
    state
  end
end
