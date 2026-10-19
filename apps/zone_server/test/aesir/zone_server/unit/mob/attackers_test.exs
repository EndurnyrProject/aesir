defmodule Aesir.ZoneServer.Unit.Mob.AttackersTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.Attackers
  alias Aesir.ZoneServer.Unit.Mob.Handlers.AiHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "owner_attackers"

  setup :setup_ets_tables

  test "a player's standing attack counts without calling its session" do
    owner = %PlayerState{character_id: 100, map_name: @map, x: 20, y: 20}
    UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())

    attacker = %PlayerState{
      character_id: 200,
      map_name: @map,
      x: 21,
      y: 20,
      combat_target_id: 100,
      action_state: :attacking,
      continuous_attack_timer: make_ref()
    }

    UnitRegistry.register_unit(:player, 200, PlayerState, attacker, self())
    SpatialIndex.add_unit(:player, 200, 21, 20, @map)

    assert Attackers.random(owner) == {:ok, {:player, 200}}
    refute_received {:"$gen_call", _, _}

    UnitRegistry.update_unit_state(:player, 200, %{attacker | continuous_attack_timer: nil})
    assert Attackers.random(owner) == :none
  end

  test "a player's cast target counts without a standing attack" do
    owner = %PlayerState{character_id: 100, map_name: @map, x: 20, y: 20}
    UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())

    caster = %PlayerState{
      character_id: 200,
      map_name: @map,
      x: 21,
      y: 20,
      casting: %{target: {:unit, 100}}
    }

    UnitRegistry.register_unit(:player, 200, PlayerState, caster, self())
    SpatialIndex.add_unit(:player, 200, 21, 20, @map)

    assert Attackers.random(owner) == {:ok, {:player, 200}}
  end

  test "homunculus and monster casts count, but chase intent and ground casts do not" do
    owner = %PlayerState{character_id: 100, map_name: @map, x: 20, y: 20}
    UnitRegistry.register_unit(:player, 100, PlayerState, owner, self())
    SpatialIndex.add_unit(:player, 100, 20, 20, @map)
    UnitRegistry.update_unit_state(:player, 100, %{owner | casting: %{target: {:unit, 100}}})
    assert Attackers.random(owner) == :none

    homunculus = %HomunculusState{
      id: 1,
      owner_character_id: 300,
      class_id: 6_004,
      name: "Vanilmirth",
      world_gid: 400,
      map_name: @map,
      x: 21,
      y: 20,
      target: {:player, 100},
      action_state: :moving
    }

    UnitRegistry.register_unit(:homunculus, 400, HomunculusState, homunculus, self())
    SpatialIndex.add_unit(:homunculus, 400, 21, 20, @map)
    assert Attackers.random(owner) == :none

    UnitRegistry.update_unit_state(:homunculus, 400, %{
      homunculus
      | casting: %{target: {:unit, {:player, 100}}}
    })

    assert Attackers.random(owner) == {:ok, {:homunculus, 400}}

    UnitRegistry.update_unit_state(:homunculus, 400, %{homunculus | action_state: :attacking})
    assert Attackers.random(owner) == {:ok, {:homunculus, 400}}
    UnitRegistry.unregister_unit(:homunculus, 400)

    mob = %MobState{
      instance_id: 500,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      map_name: @map,
      x: 21,
      y: 20,
      hp: 100,
      sp: 0,
      spawned_at: 0,
      target_ref: {:player, 100}
    }

    UnitRegistry.register_unit(:mob, 500, MobState, mob, self())
    SpatialIndex.add_unit(:mob, 500, 21, 20, @map)
    assert Attackers.random(owner) == :none

    UnitRegistry.update_unit_state(:mob, 500, %{
      mob
      | casting: %{unit_target: {:unit, :player, 100}}
    })

    assert Attackers.random(owner) == {:ok, {:mob, 500}}

    UnitRegistry.update_unit_state(:mob, 500, %{mob | casting: %{unit_target: nil}})
    assert Attackers.random(owner) == :none
  end

  test "Castling redirects a selected monster's cast as well as its attack and chase" do
    mob = %MobState{
      instance_id: 500,
      mob_id: 1,
      mob_data: nil,
      spawn_ref: nil,
      map_name: @map,
      x: 21,
      y: 20,
      hp: 100,
      sp: 0,
      spawned_at: 0,
      target_ref: {:player, 999},
      chase_target: {:player, 999},
      casting: %{unit_target: {:unit, :player, 100}}
    }

    UnitRegistry.register_unit(:mob, 500, MobState, mob, self())

    assert {:reply, :ok, redirected} =
             AiHandler.handle_redirect_target(mob, {:player, 100}, {:homunculus, 400})

    assert redirected.target_ref == {:homunculus, 400}
    assert redirected.attack_target == {:homunculus, 400}
    assert redirected.chase_target == {:homunculus, 400}
    assert redirected.casting.unit_target == {:unit, :homunculus, 400}
  end
end
