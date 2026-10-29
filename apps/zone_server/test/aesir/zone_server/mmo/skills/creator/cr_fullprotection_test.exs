defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrFullprotectionTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Creator.CrFullprotection
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 12_101
  @target_id 12_102
  @coating_bottle_id 7_139
  @statuses [:sc_cp_weapon, :sc_cp_shield, :sc_cp_armor, :sc_cp_helm]

  setup :setup_ets_tables

  setup do
    caster = player_state(@caster_id)
    :ok = UnitRegistry.register_player(caster, self())
    :ok = SpatialIndex.add_player(@caster_id, caster.x, caster.y, caster.map_name)
    :ok = SpatialIndex.add_player(@target_id, caster.x, caster.y, caster.map_name)
    :ok
  end

  test "coats every worn piece for two minutes per level" do
    register_target(%Equipment{right_hand: 1101, left_hand: 2101, armor: 2301, head_top: 5001})

    assert {:ok, _caster} = SkillInterpreter.cast(game_state(), 479, 3, {:unit, @target_id})

    for status <- @statuses do
      assert %{val1: 3, expires_at: expires_at, started_at: started_at} =
               StatusStorage.get_status(:player, @target_id, status)

      assert expires_at - started_at == 360_000
    end
  end

  test "coats only the pieces the target wears" do
    register_target(%Equipment{right_hand: 1116, left_hand: 1116})
    assert {:ok, _caster} = SkillInterpreter.cast(game_state(), 479, 1, {:unit, @target_id})
    assert coated() == [:sc_cp_weapon, :sc_cp_shield]

    Enum.each(@statuses, &StatusStorage.remove_status(:player, @target_id, &1))
    register_target(%Equipment{left_hand: 2101})
    assert {:ok, _caster} = SkillInterpreter.cast(game_state(), 479, 1, {:unit, @target_id})
    assert coated() == [:sc_cp_shield]
  end

  test "a target wearing nothing fails and keeps the Coating Bottle" do
    register_target(%Equipment{})

    assert {:failed, failed, :invalid_target} =
             SkillInterpreter.cast(game_state(), 479, 5, {:unit, @target_id})

    assert failed.inventory[0].amount == 1
    assert failed.stats.current_state.sp == 60
    assert coated() == []
  end

  test "a monster target fails and keeps the Coating Bottle" do
    assert {:ok, definition} = Catalog.by_id(479)

    assert {:failed, _caster, :invalid_target, :spare_items} =
             CrFullprotection.cast(game_state(), {:unit, {:mob, 50_001}}, 1, definition)
  end

  defp coated, do: Enum.filter(@statuses, &StatusStorage.get_status(:player, @target_id, &1))

  defp register_target(equipment) do
    :ok = UnitRegistry.register_player(player_state(@target_id, equipment), self())
  end

  defp game_state do
    %{
      character_id: @caster_id,
      x: 100,
      y: 100,
      map_name: "prontera",
      zeny: 0,
      skill_cooldowns: %{},
      act_delay_until: 0,
      inventory: %{0 => %InventoryItem{nameid: @coating_bottle_id, amount: 1, equip: 0}},
      pending_inventory_persist: [],
      stats: %{
        base_stats: %{dex: 1, int: 1},
        current_state: %{sp: 100, hp: 100},
        derived_stats: %{max_sp: 100, max_hp: 100},
        progression: %{learned_skills: %{479 => 5}}
      }
    }
    |> PlayerStateFixture.build()
  end

  defp player_state(character_id, equipment \\ %Equipment{}) do
    %Character{
      id: character_id,
      account_id: character_id,
      name: "Player#{character_id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      class: 0,
      base_level: 1,
      job_level: 1,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1
    }
    |> PlayerState.new()
    |> then(fn state -> %{state | stats: %{state.stats | equipment: equipment}} end)
  end
end
