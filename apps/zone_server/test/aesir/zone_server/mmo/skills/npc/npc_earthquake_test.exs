defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquakeTest do
  use ExUnit.Case, async: false
  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.SplashTargets
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Npc.NpcEarthquake
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator

  setup :set_mimic_private
  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Mimic.copy(DamageInputs)
    Mimic.copy(SplashTargets)
    :ok
  end

  @caster_id 5002
  @map_name "prontera"
  @center {200, 200}

  defp group(level) do
    %Group{
      group_id: 1,
      skill_id: 653,
      skill_name: :npc_earthquake,
      level: level,
      caster_id: @caster_id,
      caster_type: :mob,
      map_name: @map_name,
      center: @center,
      cells: [@center],
      interval: 300,
      state: %{}
    }
  end

  defp caster, do: %{unit_id: @caster_id, unit_type: :mob, map_name: @map_name}

  defp strike(level, enemies, atk_rate) do
    test_pid = self()
    caster = caster()
    stub(Combat, :resolve_combatant, fn :mob, @caster_id -> {:ok, caster} end)
    stub(DamageInputs, :non_player_base_attack, fn ^caster, _opts -> {:ok, 1_000} end)
    stub(ModifierCalculator, :get_all_modifiers, fn :mob, @caster_id -> %{atk_rate: atk_rate} end)
    stub(SplashTargets, :select, fn @map_name, @center, 13, ^caster -> enemies end)

    stub(Combat, :apply_skill_unit_damage, fn ^caster,
                                              :player,
                                              42,
                                              653,
                                              ^level,
                                              :neutral,
                                              100,
                                              opts ->
      send(test_pid, {:strike, opts[:base_damage], opts[:ignore_mdef]})
      :ok
    end)

    assert {:ok, %Group{}} = NpcEarthquake.on_unit_hit(group(level), @center, {:player, 42}, 0)
  end

  test "is one cell reaching five to thirteen cells by level, ignoring Land Protector" do
    assert {:ok, placement} = NpcEarthquake.on_place(group(1))
    assert placement.cells == [@center]
    assert %{unit_range: 5, interval: 300, duration: 910} = placement
    assert placement.state == %{ignore_land_protector: true}
    refute Map.has_key?(placement, :path_check) or Map.has_key?(placement, :no_overlap)

    assert {:ok, %{unit_range: 13}} = NpcEarthquake.on_place(group(5))
    assert {:ok, %{unit_range: 5}} = NpcEarthquake.on_place(group(6))
    assert {:ok, %{unit_range: 13}} = NpcEarthquake.on_place(group(12))
  end

  @tag game_mode: :renewal
  test "renewal splits the level rate of the monster's attack over the enemies in its splash" do
    strike(10, [{:player, 42}, {:player, 43}, {:mob, 44}], 20)

    # 1000 * (200 + 1000 + 500 + 100) / 100 = 18000, over three enemies.
    assert_received {:strike, 6_000, true}
  end

  @tag game_mode: :pre_renewal
  test "classic raises the attack by the monster's attack percent and a lone enemy takes it all" do
    strike(10, [{:player, 42}], 20)

    # 1000 * 120 / 100 = 1200; 1200 * 1800 / 100 = 21600.
    assert_received {:strike, 21_600, true}
  end

  test "strikes nobody while its caster is gone" do
    stub(Combat, :resolve_combatant, fn :mob, @caster_id -> {:error, :target_not_found} end)

    assert [] = NpcEarthquake.unit_targets(group(1), @center, [{:player, 42}])
  end
end
