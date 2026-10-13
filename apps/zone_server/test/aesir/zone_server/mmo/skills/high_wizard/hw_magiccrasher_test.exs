defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwMagiccrasherTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.HighWizard.HwMagiccrasher
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  defp player do
    PlayerState.new(%Character{
      id: 1001,
      account_id: 1001,
      name: "HighWizard",
      class: 4010,
      sex: "M",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 99,
      int: 90,
      hp: 100,
      sp: 100
    })
  end

  defp mob do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    MobState.new(2001, definition, spawn, "prontera", 100, 100)
  end

  test "a player strikes through the Stave Crasher path with the weapon element and no crit" do
    caster = player()

    expect(Combat, :execute_stave_crasher_attack, fn ^caster, 3001, opts ->
      assert opts[:skill_id] == 365
      assert opts[:skip_crit]
      assert opts[:skip_range]
      refute Keyword.has_key?(opts, :element)
      :ok
    end)

    assert {:ok, ^caster} =
             HwMagiccrasher.cast(caster, {:unit, 3001}, 1, HwMagiccrasher.definition())
  end

  test "mob casters strike through the same path" do
    caster = mob()

    expect(Combat, :execute_stave_crasher_attack, fn ^caster, {:player, 3001}, opts ->
      assert opts[:skill_id] == 365
      refute Keyword.has_key?(opts, :element)
      :ok
    end)

    assert :ok =
             HwMagiccrasher.mob_cast(
               caster,
               {:unit, :player, 3001},
               1,
               HwMagiccrasher.definition(),
               %{}
             )
  end
end
