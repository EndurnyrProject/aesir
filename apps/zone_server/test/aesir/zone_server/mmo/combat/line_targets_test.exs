defmodule Aesir.ZoneServer.Mmo.Combat.LineTargetsTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat.LineTargets
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "default line excludes a neighbour that the lane includes" do
    caster =
      %Character{
        id: 1000,
        account_id: 1000,
        name: "Lane caster",
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        hp: 100,
        sp: 100,
        class: 0,
        sex: "M"
      }
      |> PlayerState.new()
      |> PlayerState.to_combatant()

    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    for {id, x, y} <- [{2001, 105, 100}, {2002, 105, 101}] do
      mob = MobState.new(id, definition, spawn, "prontera", x, y)
      :ok = UnitRegistry.register_unit(:mob, id, MobState, mob, self())
      :ok = SpatialIndex.add_unit(:mob, id, x, y, "prontera")
    end

    assert LineTargets.select("prontera", {100, 100}, {109, 100}, caster) == [{:mob, 2001}]

    assert Enum.sort(
             LineTargets.select("prontera", {100, 100}, {109, 100}, caster, length: 14, width: 1)
           ) == [{:mob, 2001}, {:mob, 2002}]
  end
end
