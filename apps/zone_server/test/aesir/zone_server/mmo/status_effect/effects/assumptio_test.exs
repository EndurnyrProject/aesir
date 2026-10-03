defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.AssumptioTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn.SpawnArea
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Assumptio
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @player_id 36_101
  @boss_id 36_102
  @pvp_map "assumptio_pvp"

  setup :setup_ets_tables

  setup do
    player = player_state()
    :ok = UnitRegistry.register_player(player, self())
    :ok = SpatialIndex.add_player(@player_id, player.x, player.y, player.map_name)

    on_exit(fn -> MapFlags.set_runtime(@pvp_map, :pvp, false) end)

    %{player: player}
  end

  test "is a dispellable buff with the renewal icon that reaches boss mobs" do
    metadata = Assumptio.metadata()

    refute metadata.no_dispel
    assert metadata.bypass_boss_immunity
    assert metadata.calc_flags == [:def]
    assert metadata.icon == :assumptio2
  end

  describe "renewal" do
    @describetag game_mode: :renewal

    test "adds 50 hard DEF per level to a player", %{player: player} do
      before = Stats.calculate_stats(player.stats, @player_id, []).combat_stats.def

      :ok = apply_assumptio(:player, @player_id, @player_id)

      after_def = Stats.calculate_stats(player.stats, @player_id, []).combat_stats.def
      assert after_def - before == 250
    end

    test "adds 50 DEF per level to a boss mob buffed by another mob" do
      mob = register_boss()
      before = MobState.to_combatant(mob).combat_stats.def

      :ok = apply_assumptio(:mob, @boss_id, @boss_id + 1)

      assert MobState.to_combatant(mob).combat_stats.def - before == 250
    end

    test "leaves incoming damage unchanged" do
      assert {:ok, 900, _} = absorb(%{damage: 900, dmg_type: :physical})
    end

    test "coexists with Kyrie Eleison" do
      :ok = Interpreter.apply_status(:player, @player_id, :sc_kyrie, kyrie_params())
      :ok = apply_assumptio(:player, @player_id, @player_id)

      assert StatusStorage.has_status?(:player, @player_id, :sc_kyrie)
      assert StatusStorage.has_status?(:player, @player_id, :sc_assumptio)
    end
  end

  describe "pre-renewal" do
    @describetag game_mode: :pre_renewal

    test "halves physical, magic and misc damage on a normal map" do
      for type <- [:physical, :magic, :misc] do
        assert {:ok, 450, _} = absorb(%{damage: 900, dmg_type: type})
      end
    end

    test "cuts damage to two thirds on a PvP map" do
      :ok = SpatialIndex.update_position(@player_id, 100, 100, @pvp_map)
      :ok = MapFlags.set_runtime(@pvp_map, :pvp, true)

      assert {:ok, 600, _} = absorb(%{damage: 900, dmg_type: :magic})
    end

    test "adds no DEF", %{player: player} do
      before = Stats.calculate_stats(player.stats, @player_id, []).combat_stats.def

      :ok = apply_assumptio(:player, @player_id, @player_id)

      assert Stats.calculate_stats(player.stats, @player_id, []).combat_stats.def == before
    end

    test "Kyrie Eleison and Assumptio replace each other" do
      :ok = Interpreter.apply_status(:player, @player_id, :sc_kyrie, kyrie_params())
      :ok = apply_assumptio(:player, @player_id, @player_id)

      refute StatusStorage.has_status?(:player, @player_id, :sc_kyrie)

      :ok = Interpreter.apply_status(:player, @player_id, :sc_kyrie, kyrie_params())

      refute StatusStorage.has_status?(:player, @player_id, :sc_assumptio)
      assert StatusStorage.has_status?(:player, @player_id, :sc_kyrie)
    end
  end

  defp absorb(hit_info) do
    entry = %StatusEntry{type: :sc_assumptio, val1: 5}
    Assumptio.absorb_damage({:player, @player_id}, entry, hit_info, %{})
  end

  defp apply_assumptio(unit_type, unit_id, caster_id) do
    Interpreter.apply_status(unit_type, unit_id, :sc_assumptio,
      val1: 5,
      duration: 100_000,
      caster_id: caster_id
    )
  end

  defp kyrie_params,
    do: [val1: 10, val2: 1_000, val3: 10, duration: 120_000, caster_id: @player_id]

  defp register_boss do
    mob_data = %MobDefinition{
      id: 1086,
      aegis_name: "GOLDEN_BUG",
      name: "Golden Thief Bug",
      level: 65,
      hp: 222_750,
      sp: 0,
      stats: %{str: 65, agi: 75, vit: 35, int: 45, dex: 85, luk: 150},
      atk: 870,
      matk: 0,
      def: 60,
      mdef: 45,
      attack_range: 1,
      skill_range: 10,
      chase_range: 12,
      walk_speed: 100,
      attack_delay: 768,
      attack_motion: 768,
      client_attack_motion: 768,
      damage_motion: 480,
      element: {:fire, 2},
      race: :insect,
      size: :large,
      modes: [:boss]
    }

    spawn_ref = %MobSpawn{
      mob: 1086,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %SpawnArea{x: 100, y: 100}
    }

    state = MobState.new(@boss_id, mob_data, spawn_ref, "prontera", 100, 100)
    UnitRegistry.register_unit(:mob, @boss_id, MobState, state, self())
    state
  end

  defp player_state do
    PlayerState.new(%Character{
      id: @player_id,
      account_id: @player_id,
      name: "Assumptio #{@player_id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "F",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 99,
      job_level: 50,
      class: 4009
    })
  end
end
