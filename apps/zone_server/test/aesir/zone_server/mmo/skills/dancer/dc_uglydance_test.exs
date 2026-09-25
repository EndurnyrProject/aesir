defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcUglydanceTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Performance
  alias Aesir.ZoneServer.Mmo.Skills.Dancer.DcUglydance
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Resource

  @caster_id 1_000
  @whip_id 90_325

  setup :verify_on_exit!
  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    Catalog.reload()
    MapFlags.reload()

    stub(ItemManagement, :get_item_by_id, fn @whip_id ->
      {:ok,
       %ItemDefinition{
         id: @whip_id,
         aegis_name: "task11_whip",
         name: "Task 11 Whip",
         type: :weapon,
         subtype: :whip,
         weapon_level: 1
       }}
    end)

    :ok
  end

  @tag game_mode: :renewal
  test "defines the pinned Hip Shaker table and is cataloged as a performance" do
    assert {:ok, DcUglydance} = Catalog.active_module_for(:dc_uglydance)
    assert {:ok, definition} = Catalog.by_id(325)

    assert definition.name == :dc_uglydance
    assert definition.display_name == "Hip Shaker"
    assert definition.max_level == 5
    assert definition.target_type == :self
    assert definition.splash_radius == 4
    assert definition.require_weapon == [:whip]
    assert definition.sp_cost == [23, 26, 29, 32, 35]
    assert definition.cast_time == List.duplicate(1_000, 5)
    assert definition.fixed_cast_time == List.duplicate(300, 5)
    assert definition.after_cast_delay == List.duplicate(300, 5)
    assert definition.cooldown == List.duplicate(5_000, 5)
    assert Catalog.performance?(325)
  end

  test "is rejected on a map without a versus flag" do
    assert {:error, :versus_map_only} =
             DcUglydance.validate(player_state(), :self, 1, DcUglydance.definition())
  end

  @tag game_mode: :renewal
  test "drains every enemy in radius and remembers the completed performance on versus maps" do
    :ok = MapFlags.set_runtime("prontera", :pvp, true)
    Mimic.copy(Resource)

    assert :ok = DcUglydance.validate(player_state(), :self, 1, DcUglydance.definition())

    for {amount, level} <- Enum.with_index([12, 14, 16, 18, 20], 1) do
      caster = player_state()

      expect(Combat, :splash_targets, fn "prontera", {10, 20}, 4, @caster_id ->
        [{:player, 2_000}, {:mob, 3_000}]
      end)

      expect(Resource, :drain_sp, fn :player, 2_000, ^amount -> :ok end)
      expect(Resource, :drain_sp, fn :mob, 3_000, ^amount -> :ok end)

      assert {:ok, %{last_song: %{skill_id: 325, level: ^level}}} =
               DcUglydance.cast(caster, :self, level, DcUglydance.definition())
    end
  end

  defp player_state do
    %PlayerState{
      character_id: @caster_id,
      x: 10,
      y: 20,
      map_name: "prontera",
      stats: %Stats{
        base_stats: %{dex: 1, int: 1},
        current_state: %{hp: 100, sp: 100},
        derived_stats: %{max_hp: 100, max_sp: 100},
        progression: %PlayerProgression{learned_skills: %{325 => 5}},
        equipment: %Equipment{right_hand: @whip_id}
      }
    }
  end

  @tag game_mode: :pre_renewal
  test "classic carries the source's instant cast" do
    definition = DcUglydance.definition()
    assert definition.sp_cost == [23, 26, 29, 32, 35]
    assert definition.cast_time == []
    assert definition.fixed_cast_time == []
    assert definition.after_cast_delay == []
    assert definition.cooldown == []
  end

  @tag game_mode: :pre_renewal
  test "classic places a 30-second enemy field with three-second SP drain" do
    caster = player_state()
    :ok = MapFlags.set_runtime("prontera", :pvp, true)
    assert :ok = DcUglydance.validate(caster, :self, 3, DcUglydance.definition())
    reject(&Combat.splash_targets/4)

    expect(Performance, :perform, fn ^caster, definition, 3, nil, [], opts ->
      assert definition.duration == List.duplicate(30_000, 5)
      assert opts[:kind] == :dance
      assert opts[:reach] == :enemy
      assert opts[:linger_ms] == 0
      assert opts[:upkeep] == 3
      assert opts[:tick] == :ugly_dance
      assert opts[:tick_interval] == 3_000
      {:ok, caster}
    end)

    assert {:ok, ^caster} = DcUglydance.cast(caster, :self, 3, DcUglydance.definition())
  end

  @tag game_mode: :pre_renewal
  test "mob casting keeps the immediate splash" do
    Mimic.copy(Resource)

    mob = %MobState{
      instance_id: @caster_id,
      mob_id: 1002,
      mob_data: nil,
      spawn_ref: nil,
      x: 10,
      y: 20,
      map_name: "prontera",
      hp: 100,
      max_hp: 100,
      sp: 100,
      max_sp: 100,
      spawned_at: 0
    }

    expect(Combat, :splash_targets, fn "prontera", {10, 20}, 4, @caster_id ->
      [{:player, 2_000}]
    end)

    expect(Resource, :drain_sp, fn :player, 2_000, 20 -> :ok end)
    reject(&Performance.perform/6)

    assert {:ok, ^mob} =
             DcUglydance.cast(mob, {:unit, @caster_id}, 3, DcUglydance.definition())
  end
end
