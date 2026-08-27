defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.DefenderProcStatusesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.DefSet
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MdefSet
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.NoRecoverState
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry

  test "the three equipment proc statuses are registered with player-only semantics" do
    assert %{
             module: DefSet,
             icon: :set_num_def,
             bypass_resistance: true,
             target_types: [:player]
           } = Registry.get_definition(:sc_defset)

    assert %{
             module: MdefSet,
             icon: :set_num_mdef,
             bypass_resistance: true,
             target_types: [:player]
           } = Registry.get_definition(:sc_mdefset)

    assert %{
             module: NoRecoverState,
             icon: :handicapstate_norecover,
             bypass_resistance: true,
             target_types: [:player]
           } = Registry.get_definition(:sc_norecover_state)
  end
end
