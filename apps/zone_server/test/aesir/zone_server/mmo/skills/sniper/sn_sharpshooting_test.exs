defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnSharpshootingTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.SnSharpshooting
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  defp player do
    PlayerState.new(%Character{
      id: 1001,
      account_id: 1001,
      name: "Sniper",
      class: 4012,
      sex: "M",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      base_level: 99,
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

  @tag game_mode: :renewal
  test "renewal uses target-centred splash and normal weapon variance on crits" do
    caster = player()
    stub(Combat, :resolve_combatant, fn 3001 -> {:ok, %{position: {109, 100}}} end)

    expect(Combat, :execute_splash_attack, fn ^caster, {109, 100}, 2, opts ->
      assert opts[:skill_ratio] == 1800
      assert opts[:critical]
      assert opts[:critical_rate_bonus] == 30
      assert opts[:critical_max_weapon] == false
      assert opts[:ranged]
      assert opts[:target_skill_units]
      [3001]
    end)

    assert {:ok, ^caster} =
             SnSharpshooting.cast(caster, {:unit, 3001}, 5, SnSharpshooting.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic empty lane falls back to the target without a weapon range check" do
    caster = player()

    expect(Combat, :execute_line_attack, fn ^caster, 3001, opts ->
      assert opts[:skill_ratio] == 450
      assert opts[:length] == 14
      assert opts[:width] == 1
      assert opts[:ranged]
      assert opts[:critical]
      assert opts[:critical_rate_bonus] == 20
      []
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, 3001, opts ->
      assert opts[:skip_range]
      assert opts[:skill_ratio] == 450
      assert opts[:critical]
      assert opts[:critical_rate_bonus] == 20
      :ok
    end)

    assert {:ok, ^caster} =
             SnSharpshooting.cast(caster, {:unit, 3001}, 5, SnSharpshooting.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic connected lane does not deliver a fallback hit" do
    caster = player()
    stub(Combat, :execute_line_attack, fn ^caster, 3001, _opts -> [3001] end)
    reject(&Combat.execute_skill_attack/3)

    assert {:ok, ^caster} =
             SnSharpshooting.cast(caster, {:unit, 3001}, 5, SnSharpshooting.definition())
  end

  @tag game_mode: :pre_renewal
  test "classic mob lane and fallback have different ratios and preserve typed target" do
    caster = mob()

    expect(Combat, :execute_line_attack, fn ^caster, {:player, 3001}, opts ->
      assert opts[:skill_ratio] == 420
      []
    end)

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 3001}, opts ->
      assert opts[:skill_ratio] == 350
      assert opts[:skip_range]
      :ok
    end)

    assert :ok =
             SnSharpshooting.mob_cast(
               caster,
               {:unit, :player, 3001},
               3,
               SnSharpshooting.definition(),
               %{}
             )
  end
end
