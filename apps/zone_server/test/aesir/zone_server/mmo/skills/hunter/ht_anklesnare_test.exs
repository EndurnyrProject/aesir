defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnareTest do
  use ExUnit.Case, async: false

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.HtAnklesnare
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_runtime_tables

  @player_id 10_001
  @mob_id 20_001
  @map "prontera"

  describe "definition and duration" do
    test "uses canonical resources, armed lifetimes, and AGI/caster-level duration" do
      definition = HtAnklesnare.definition()

      assert definition.id == 117
      assert definition.max_level == 5
      assert definition.range == 3
      assert definition.sp_cost == List.duplicate(12, 5)
      assert definition.item_cost == [%{id: 1065, amount: 1}]
      assert definition.unit_duration == [250_000, 200_000, 150_000, 100_000, 50_000]

      assert Enum.map(1..5, &HtAnklesnare.capture_duration(&1, 0, 1)) ==
               [4_000, 8_000, 12_000, 16_000, 20_000]

      assert HtAnklesnare.capture_duration(5, 100, 50) == 10_000
      assert HtAnklesnare.capture_duration(1, 200, 50) == 4_500
    end
  end

  describe "placement and capture" do
    test "places one hidden armed cell with paid natural return metadata" do
      register_player(@player_id, base_level: 50)

      placed = %{
        group(:player, @player_id, level: 3)
        | state: %{cast_origin: :normal, paid_return?: true}
      }

      assert {:ok, placement} = HtAnklesnare.on_place(placed)
      assert placement.cells == [{50, 50}]
      assert placement.visibility == :none
      assert placement.duration == 150_000
      assert placement.state.ignore_land_protector

      assert %{__struct__: TrapState, phase: :armed, return_item_on_expiry?: true} =
               placement.state.trap
    end

    test "a player-owned snare captures a monster, links the status, and pulls it" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 100)
      armed = group(:player, @player_id, level: 5)

      assert {:ok, captured} = HtAnklesnare.on_touch(armed, {:mob, @mob_id})

      assert %{
               __struct__: Group,
               visibility: :public,
               target_type: :mob,
               target_id: @mob_id,
               state: %{trap: %{__struct__: TrapState, phase: :captured, link_id: link_id}}
             } = captured

      assert is_integer(link_id)

      assert %{state: %{group_id: 1, link_id: ^link_id}} =
               StatusStorage.get_status(:mob, @mob_id, :sc_anklesnare)
    end

    test "a mob-owned snare captures a player and ignores same-side contacts" do
      register_mob(@mob_id, level: 80, agi: 30)
      register_player(@player_id, base_level: 50, agi: 100)

      mob_group = group(:mob, @mob_id, level: 1)

      assert {:ok, captured} = HtAnklesnare.on_touch(mob_group, {:player, @player_id})
      assert captured.target_type == :player
      assert captured.target_id == @player_id
      assert StatusStorage.has_status?(:player, @player_id, :sc_anklesnare)

      assert {:ok, ^mob_group} = HtAnklesnare.on_touch(mob_group, {:mob, @mob_id + 1})
    end

    test "a status-immune target leaves the armed trap unchanged" do
      register_player(@player_id, base_level: 50)
      register_mob(@mob_id, level: 20, agi: 100, modes: [:status_immune])
      armed = group(:player, @player_id, level: 5)

      assert {:ok, ^armed} = HtAnklesnare.on_touch(armed, {:mob, @mob_id})
      refute StatusStorage.has_status?(:mob, @mob_id, :sc_anklesnare)
    end

    test "a missing target leaves the armed trap unchanged" do
      register_player(@player_id, base_level: 50)
      armed = group(:player, @player_id)

      assert {:ok, ^armed} = HtAnklesnare.on_touch(armed, {:mob, @mob_id})
    end
  end

  defp setup_runtime_tables(context) do
    apply(Elixir.Aesir.TestEtsSetup, :setup_ets_tables, [context])
  end

  defp group(caster_type, caster_id, opts \\ []) do
    %Group{
      group_id: 1,
      skill_id: 117,
      skill_name: :ht_anklesnare,
      level: Keyword.get(opts, :level, 1),
      caster_id: caster_id,
      caster_type: caster_type,
      map_name: @map,
      center: {50, 50},
      cells: [{50, 50}],
      next_tick_at: 0,
      expires_at: 250_000,
      interval: 1_000,
      visibility: :none,
      state: %{trap: %TrapState{reclaim_item_id: 1065}}
    }
  end

  defp register_player(id, opts) do
    state =
      %Character{
        id: id,
        account_id: id,
        name: "Ankle#{id}",
        last_map: @map,
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: Keyword.get(opts, :agi, 1),
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: Keyword.fetch!(opts, :base_level),
        job_level: 1,
        class: 0
      }
      |> PlayerState.new()

    :ok = UnitRegistry.register_player(state, self())
    :ok = SpatialIndex.add_unit(:player, id, 50, 50, @map)
    state
  end

  defp register_mob(id, opts) do
    level = Keyword.get(opts, :level, 20)
    agi = Keyword.get(opts, :agi, 20)

    definition =
      %MobDefinition{
        id: 1002,
        aegis_name: "TEST_MOB",
        name: "Test Mob",
        level: level,
        hp: 1_000,
        sp: 50,
        atk: 10,
        matk: 0,
        def: 5,
        mdef: 3,
        stats: %{str: 10, agi: agi, vit: 10, int: 5, dex: 10, luk: 5},
        attack_range: 1,
        element: {:neutral, 1},
        race: :formless,
        size: :medium,
        walk_speed: 200,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400,
        modes: Keyword.get(opts, :modes, []),
        drops: []
      }

    spawn =
      %MobSpawn{
        mob: definition.id,
        amount: 1,
        respawn_time: 5_000,
        spawn_area: %MobSpawn.SpawnArea{x: 50, y: 50}
      }

    state = MobState.new(id, definition, spawn, @map, 50, 50)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, 50, 50, @map)
    state
  end
end
