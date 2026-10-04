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

  @lowest_roll [rng: &__MODULE__.lowest/1]

  @doc false
  def lowest(_range), do: 1

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

  defp matk_min(caster), do: caster.__struct__.to_combatant(caster).combat_stats.matk_min

  @tag game_mode: :renewal
  test "renewal adds the rolled MATK to a neutral ranged weapon strike" do
    caster = player()
    rolled = matk_min(caster)

    expect(Combat, :execute_skill_attack, fn ^caster, 3001, opts ->
      assert opts[:bonus_atk] == rolled
      refute Keyword.has_key?(opts, :base_damage)
      assert opts[:element] == :neutral
      assert opts[:skip_range]
      :ok
    end)

    assert {:ok, ^caster} =
             HwMagiccrasher.cast(
               caster,
               {:unit, 3001},
               1,
               HwMagiccrasher.definition(),
               @lowest_roll
             )
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal replaces the weapon base with the rolled MATK and skips status ATK" do
    caster = player()
    rolled = matk_min(caster)

    expect(Combat, :execute_skill_attack, fn ^caster, 3001, opts ->
      assert opts[:base_damage] == rolled
      assert opts[:skip_status_atk]
      refute Keyword.has_key?(opts, :bonus_atk)
      :ok
    end)

    assert {:ok, ^caster} =
             HwMagiccrasher.cast(
               caster,
               {:unit, 3001},
               1,
               HwMagiccrasher.definition(),
               @lowest_roll
             )
  end

  test "mob casters strike through the same path" do
    caster = mob()

    expect(Combat, :execute_skill_attack, fn ^caster, {:player, 3001}, opts ->
      assert opts[:skill_id] == 365
      assert opts[:element] == :neutral
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

  describe "rolled_matk/2" do
    test "rolls within [matk_min, matk_max)" do
      combatant = %{combat_stats: %{matk_min: 100, matk_max: 150}}

      assert HwMagiccrasher.rolled_matk(combatant, fn 50 -> 1 end) == 100
      assert HwMagiccrasher.rolled_matk(combatant, fn 50 -> 50 end) == 149
    end

    test "a flat band rolls its single value" do
      assert HwMagiccrasher.rolled_matk(%{combat_stats: %{matk_min: 60, matk_max: 60}}, fn 1 ->
               1
             end) ==
               60
    end
  end
end
