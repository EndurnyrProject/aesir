defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgArrowvulcanTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Clown.CgArrowvulcan
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Mob.MobState

  setup :set_mimic_private
  setup :verify_on_exit!

  test "a player volley is one ranged strike displayed as nine hits" do
    caster =
      PlayerStateFixture.build(%{character_id: 17, stats: %{progression: %{base_level: 99}}})

    expect(Combat, :execute_skill_attack, fn ^caster, 18, opts ->
      assert opts[:skill_ratio] == if(GameMode.mode() == :renewal, do: 1485, else: 1200)
      assert opts[:skill_id] == 394
      assert opts[:skill_level] == 10
      assert opts[:display_hit_count] == 9
      assert opts[:skip_range]
      assert opts[:skip_crit]
      assert opts[:ranged]
      :ok
    end)

    assert {:ok, ^caster} =
             CgArrowvulcan.cast(caster, {:unit, 18}, 10, CgArrowvulcan.definition())
  end

  test "mob casting preserves the typed target and uses the mob's base level" do
    {:ok, definition} = Mobs.by_id(1002)

    spawn = %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100, xs: 0, ys: 0}
    }

    caster = MobState.new(19, %{definition | level: 50}, spawn, "prontera", 100, 100)

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 18}, opts ->
      assert opts[:skill_ratio] == if(GameMode.mode() == :renewal, do: 750, else: 1200)
      assert opts[:display_hit_count] == 9
      :ok
    end)

    assert :ok =
             CgArrowvulcan.mob_cast(
               caster,
               {:unit, :player, 18},
               10,
               CgArrowvulcan.definition(),
               %{}
             )
  end

  test "failed combat resolution does not claim a successful cast" do
    caster =
      PlayerStateFixture.build(%{character_id: 17, stats: %{progression: %{base_level: 99}}})

    stub(Combat, :execute_skill_attack, fn _, _, _ -> {:error, :target_not_found} end)

    assert {:error, :target_not_found} =
             CgArrowvulcan.cast(caster, {:unit, 18}, 10, CgArrowvulcan.definition())
  end
end
