defmodule Aesir.ZoneServer.Unit.Player.StatsAttackRangeTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.EquipmentFold
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers

  setup :set_mimic_private

  test "folds each weapon's item range, the longer hand and the unarmed floor" do
    definitions =
      [{1, :revolver, 7}, {2, :bow, 5}, {3, :whip, 2}, {4, :spear, 3}, {5, :dagger, 1}]
      |> Map.new(fn {id, subtype, range} ->
        {id,
         %ItemDefinition{
           id: id,
           aegis_name: "test",
           name: "test",
           type: :weapon,
           subtype: subtype,
           range: range
         }}
      end)

    stub(ItemManagement, :get_item_by_id, &Map.fetch(definitions, &1))

    for {id, expected} <- [{1, 7}, {2, 5}, {3, 2}, {4, 3}, {5, 1}] do
      assert Stats.attack_range(fold([item(id, 2)])) == expected
    end

    assert Stats.attack_range(fold([item(5, 2), item(4, 32)])) == 3
    assert Stats.attack_range(fold([])) == 1
  end

  test "passive range adds to item reach but not caster weapon range" do
    bow = %InventoryItem{nameid: 1701, amount: 1, equip: 34, identify: 1}
    stats = fold([bow])
    stats = %{stats | modifiers: %{stats.modifiers | passive: %{range: 4}}}

    assert Stats.attack_range(stats) == 9
    assert Caster.Player.attack_range(struct(PlayerState, stats: stats)) == 5
  end

  test "caster_range_unfolded_stats_fallback_test" do
    equipment = %Stats.Equipment{right_hand: 1701}
    stats = %Stats{equipment: equipment, modifiers: %Modifiers{}}

    assert Caster.Player.attack_range(struct(PlayerState, stats: stats)) == 9
  end

  test "mob caster skill range remains independent of player equipment" do
    mob = struct(MobState, mob_data: %{skill_range: 7})
    assert Caster.Mob.attack_range(mob) == 7
  end

  defp item(id, equip), do: %InventoryItem{nameid: id, amount: 1, equip: equip, identify: 1}

  defp fold(items) do
    %Stats{
      progression: %{base_level: 1, job_level: 1, job_id: 0, learned_skills: %{}},
      modifiers: %Modifiers{}
    }
    |> EquipmentFold.apply_equipment_modifiers(items)
  end
end
