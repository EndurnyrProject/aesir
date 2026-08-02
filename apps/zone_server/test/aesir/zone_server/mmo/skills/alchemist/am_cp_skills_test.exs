defmodule Aesir.ZoneServer.Mmo.Skills.Alchemist.AmCpSkillsTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 12_001
  @target_id 12_002
  @coating_bottle_id 7139

  setup :setup_ets_tables

  setup do
    caster = player_state(@caster_id)
    target = player_state(@target_id)

    :ok = UnitRegistry.register_player(caster, self())
    :ok = UnitRegistry.register_player(target, self())
    :ok = SpatialIndex.add_player(@caster_id, caster.x, caster.y, caster.map_name)
    :ok = SpatialIndex.add_player(@target_id, target.x, target.y, target.map_name)

    %{caster: caster, target: target}
  end

  for {skill_id, name, status, sp_cost} <- [
        {234, :am_cp_weapon, :sc_cp_weapon, 30},
        {235, :am_cp_shield, :sc_cp_shield, 25},
        {236, :am_cp_armor, :sc_cp_armor, 25},
        {237, :am_cp_helm, :sc_cp_helm, 20}
      ] do
    test "#{name} applies its protection for two minutes per level and charges its cost" do
      skill_id = unquote(skill_id)
      name = unquote(name)
      status = unquote(status)
      sp_cost = unquote(sp_cost)

      assert {:ok, definition} = Catalog.by_id(skill_id)
      assert definition.name == name
      assert definition.max_level == 5
      assert definition.target_type == :target_ally
      assert definition.sp_cost == List.duplicate(sp_cost, 5)
      assert definition.item_cost == [%{id: @coating_bottle_id, amount: 1}]

      assert {:ok, self_cast} = SkillInterpreter.cast(game_state(skill_id), skill_id, 3, :self)
      assert self_cast.stats.current_state.sp == 100 - sp_cost
      assert self_cast.inventory == %{}

      assert %{val1: 3, expires_at: expires_at, started_at: started_at} =
               StatusStorage.get_status(:player, @caster_id, status)

      assert expires_at - started_at == 360_000

      assert {:ok, other_cast} =
               SkillInterpreter.cast(game_state(skill_id), skill_id, 5, {:unit, @target_id})

      assert other_cast.stats.current_state.sp == 100 - sp_cost
      assert other_cast.inventory == %{}

      assert %{val1: 5, expires_at: expires_at, started_at: started_at} =
               StatusStorage.get_status(:player, @target_id, status)

      assert expires_at - started_at == 600_000
    end
  end

  test "AM_CP_WEAPON prevents a protected target weapon break" do
    assert {:ok, _} = SkillInterpreter.cast(game_state(234), 234, 1, {:unit, @target_id})

    target =
      {:player, @target_id,
       %Stats{
         equipment: %Equipment{right_hand: 1101},
         modifiers: %Modifiers{equipment: %{}}
       }}

    assert EquipBreak.resolve_slot(10_000, target, :weapon, rng: fn _ -> 1 end) == []
  end

  defp game_state(skill_id) do
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
        progression: %{learned_skills: %{skill_id => 5}}
      }
    }
  end

  defp player_state(character_id) do
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
  end
end
