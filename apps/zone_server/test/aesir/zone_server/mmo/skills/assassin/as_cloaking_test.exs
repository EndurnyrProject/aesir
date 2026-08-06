defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsCloakingTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.GatType
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsCloaking
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables

  test "defines Cloaking's static skill data" do
    definition = AsCloaking.definition()

    assert definition.id == 135
    assert definition.name == :as_cloaking
    assert definition.status == :sc_cloaking
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.sp_cost == List.duplicate(15, 10)
    assert definition.requires == []
  end

  test "levels one and two require initial impassable adjacency while higher levels do not" do
    player = player_state(1)
    cache(MapData.new("open", 5, 5))

    assert {:error, :impassable_neighbor_required} =
             AsCloaking.validate(player, :self, 1, AsCloaking.definition())

    assert {:error, :impassable_neighbor_required} =
             AsCloaking.validate(player, :self, 2, AsCloaking.definition())

    assert :ok = AsCloaking.validate(player, :self, 3, AsCloaking.definition())

    cache(MapData.new("open", 5, 5) |> MapData.set_cell(2, 1, GatType.wall()))
    assert :ok = AsCloaking.validate(player, :self, 1, AsCloaking.definition())
  end

  test "activation stores the cadence and wall state, clears intent, and recast toggles off" do
    cache(MapData.new("open", 5, 5) |> MapData.set_cell(2, 1, GatType.wall()))

    player =
      %{
        player_state(2)
        | movement_state: :moving,
          walk_path: [{3, 2}],
          movement_intent: :combat,
          combat_target_id: 9,
          combat_action_type: 7,
          last_target_position: {3, 2}
      }

    :ok = UnitRegistry.register_player(player, self())

    assert {:ok, activated} = AsCloaking.cast(player, :self, 1, AsCloaking.definition())
    assert activated.movement_state == :standing
    assert activated.walk_path == []
    assert activated.movement_intent == :none
    assert activated.combat_target_id == nil
    assert activated.combat_action_type == nil

    assert %{val1: 1, tick: 500, state: %{adjacent_impassable?: true}} =
             StatusStorage.get_status(:player, 2, :sc_cloaking)

    cache(MapData.new("open", 5, 5))
    assert :ok = AsCloaking.validate(activated, :self, 1, AsCloaking.definition())
    assert {:ok, ^activated} = AsCloaking.cast(activated, :self, 1, AsCloaking.definition())
    refute StatusStorage.has_status?(:player, 2, :sc_cloaking)
  end

  test "stores the exact per-level SP drain cadence" do
    cache(MapData.new("open", 5, 5) |> MapData.set_cell(2, 1, GatType.wall()))
    intervals = [500 | Enum.to_list(1_000..9_000//1_000)]

    for {expected_tick, level} <- Enum.with_index(intervals, 1) do
      player = player_state(100 + level)
      :ok = UnitRegistry.register_player(player, self())
      assert {:ok, _activated} = AsCloaking.cast(player, :self, level, AsCloaking.definition())

      assert %{tick: ^expected_tick} =
               StatusStorage.get_status(:player, 100 + level, :sc_cloaking)
    end
  end

  test "mob casting ignores adjacency and applies exactly ten seconds without a drain tick" do
    cache(MapData.new("open", 5, 5))

    mob = %MobState{
      instance_id: 3,
      mob_id: 1002,
      mob_data: %{
        modes: [],
        race: :formless,
        element: {:neutral, 1},
        size: :medium,
        stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        level: 1,
        atk: 1,
        matk: 1,
        def: 0,
        mdef: 0,
        attack_delay: 1_000
      },
      spawn_ref: %{},
      x: 2,
      y: 2,
      map_name: "open",
      hp: 100,
      max_hp: 100,
      sp: 0,
      max_sp: 0,
      spawned_at: 0
    }

    :ok = UnitRegistry.register_unit(:mob, 3, MobState, mob, self())

    assert :ok = AsCloaking.validate(mob, :self, 1, AsCloaking.definition())
    assert :ok = AsCloaking.mob_cast(mob, {:unit, :player, 99}, 1, AsCloaking.definition(), %{})

    assert %{val1: 1, tick: 0, expires_at: expires_at} =
             StatusStorage.get_status(:mob, 3, :sc_cloaking)

    assert_in_delta expires_at - System.monotonic_time(:millisecond), 10_000, 100

    assert :unchanged = StatusInterpreter.on_committed_action(:mob, 3, {:skill, 136})
    assert StatusStorage.has_status?(:mob, 3, :sc_cloaking)
    assert :changed = StatusInterpreter.on_committed_action(:mob, 3, :normal_attack)
    refute StatusStorage.has_status?(:mob, 3, :sc_cloaking)
  end

  defp cache(map), do: :ets.insert(EtsTable.table_for(:map_cache), {map.name, map})

  defp player_state(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Player #{id}",
      last_map: "open",
      last_x: 2,
      last_y: 2,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 50,
      job_level: 50,
      class: 12
    })
  end
end
