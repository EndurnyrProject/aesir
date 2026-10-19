defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaoticTargetingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "Benediction routes a rolled player attacker to that player rather than the owner" do
    owner = %PlayerState{character_id: 100, map_name: "chaotic_targeting", x: 20, y: 20}
    UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())

    attacker = %PlayerState{
      character_id: 200,
      map_name: owner.map_name,
      x: 21,
      y: 20,
      casting: %{target: {:unit, 100}}
    }

    UnitRegistry.register_unit(:player, 200, PlayerState, attacker, self())
    SpatialIndex.add_unit(:player, 200, 21, 20, owner.map_name)

    caster = %HomunculusState{
      id: 1,
      owner_character_id: 100,
      class_id: 6_004,
      name: "Vanilmirth",
      world_gid: 1_500_001,
      level: 50,
      int: 50
    }

    seed =
      Enum.find(1..100, fn n ->
        :rand.seed(:exsss, {n, n + 1, n + 2})
        :rand.uniform(100) > 50
      end)

    :rand.seed(:exsss, {seed, seed + 1, seed + 2})

    assert {:local_effects, ^caster,
            [{:external_heal, {:player, 200}, amount, {:homunculus, 1_500_001}}]} =
             HvanChaotic.cast(caster, :self, 1, HvanChaotic.definition())

    assert amount > 0
  end
end
