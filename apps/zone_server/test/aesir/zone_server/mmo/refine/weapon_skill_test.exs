defmodule Aesir.ZoneServer.Mmo.Refine.WeaponSkillTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Refine.WeaponSkill
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :set_mimic_private

  setup do
    definitions =
      Map.new(1..5, fn level ->
        id = 9_000 + level

        {id,
         %ItemDefinition{
           id: id,
           aegis_name: "Weapon#{level}",
           name: "Weapon",
           type: :weapon,
           weapon_level: level,
           refineable: true
         }}
      end)

    definitions =
      Map.put(definitions, 9_010, %{definitions[9_001] | id: 9_010, refineable: false})

    stub(Items, :by_id, &Map.fetch(definitions, &1))

    stub(RefineDatabase, :level_info, fn :weapon, 1, 4 ->
      %{chances: %{normal: %{rate: 6_755, material_nameid: 1_010}}}
    end)

    :ok
  end

  test "offer_uses_identified_unworn_weapons_and_held_ore" do
    state = %PlayerState{
      inventory: %{
        0 => weapon(10, 9_001, refine: 3),
        1 => weapon(11, 9_010),
        2 => weapon(12, 9_001, equip: 2),
        3 => weapon(13, 9_001, equip: 32),
        4 => weapon(14, 9_001, identify: 0),
        5 => weapon(15, 9_001, refine: 4),
        6 => weapon(16, 9_002),
        7 => weapon(17, 9_003),
        8 => weapon(18, 9_004),
        9 => weapon(19, 9_005),
        10 => %InventoryItem{nameid: 1_010, amount: 1},
        11 => %InventoryItem{nameid: 984, amount: 1},
        12 => weapon(22, 9_001, attribute: 1, bound: 4, expire_time: ~N[2020-01-01 00:00:00])
      }
    }

    assert WeaponSkill.offer(state, 4) == %{0 => 10, 1 => 11, 7 => 17, 8 => 18, 12 => 22}
    assert WeaponSkill.offer(state, 0) == %{}
    assert WeaponSkill.material(1) == {:ok, 1_010}
    assert WeaponSkill.material(2) == {:ok, 1_011}
    assert WeaponSkill.material(3) == {:ok, 984}
    assert WeaponSkill.material(4) == {:ok, 984}
    assert WeaponSkill.material(5) == :error
  end

  test "reply_preparation_revalidates_row_and_process" do
    state = state()
    assert {:error, :no_item} = WeaponSkill.prepare(state, 0, 999, 4)
    assert {:error, :no_item} = WeaponSkill.prepare(state, 99, 10, 4)

    assert {:error, :not_refinable} =
             WeaponSkill.prepare(put_in(state.inventory[0].nameid, 9_010), 0, 10, 4)

    assert {:error, :max_refine} = WeaponSkill.prepare(state, 0, 10, 3)

    assert {:error, :max_refine} =
             WeaponSkill.prepare(put_in(state.inventory[0].refine, 10), 0, 10, 20)

    assert {:error, :no_ore} =
             WeaponSkill.prepare(%{state | inventory: Map.delete(state.inventory, 1)}, 0, 10, 4)

    stub(RefineDatabase, :level_info, fn _, _, _ -> nil end)
    assert {:error, :not_refinable} = WeaponSkill.prepare(state, 0, 10, 4)
    stub(RefineDatabase, :level_info, fn _, _, _ -> %{chances: %{}} end)
    assert {:error, :not_refinable} = WeaponSkill.prepare(state, 0, 10, 4)

    stub(RefineDatabase, :level_info, fn _, _, _ ->
      %{chances: %{normal: %{rate: 9_999, material_nameid: 984}}}
    end)

    assert {:error, :not_refinable} = WeaponSkill.prepare(state, 0, 10, 4)
  end

  test "normal_rate_offset_is_next_refine_and_reply_does_not_repeat_offer_filters" do
    state = state()
    selected = %{state.inventory[0] | equip: 2, identify: 0}
    state = %{state | inventory: Map.put(state.inventory, 0, selected)}
    assert {:ok, context} = WeaponSkill.prepare(state, 0, 10, 4)
    assert context.item == selected
    assert context.definition.id == 9_001
    assert context.normal_rate == 6_755
    assert context.ore_index == 1
  end

  test "chance_preserves_percent_and_signed_truncation" do
    assert WeaponSkill.chance(6_755, 49, false) == 67
    assert WeaponSkill.chance(6_755, 50, false) == 67
    assert WeaponSkill.chance(6_755, 51, false) == 67
    assert WeaponSkill.chance(6_755, 70, false) == 77
    assert WeaponSkill.chance(6_755, 0, true) == 77
    assert WeaponSkill.chance(6_755, 99, true) == 77
    assert WeaponSkill.chance(0, 0, false) == -25
    assert WeaponSkill.chance(10_000, 70, false) == 110
  end

  test "strict_percent_roll_is_binary_outcome" do
    assert WeaponSkill.outcome(9, 0, 0) == {:break}
    assert WeaponSkill.outcome(9, 1, 0) == {:success, 10}
    assert WeaponSkill.outcome(3, 99, 99) == {:break}
    assert WeaponSkill.outcome(3, 100, 99) == {:success, 4}
    assert WeaponSkill.outcome(3, -1, 0) == {:break}
    assert WeaponSkill.outcome(3, 110, 99) == {:success, 4}
  end

  defp state,
    do: %PlayerState{
      inventory: %{
        0 => weapon(10, 9_001, refine: 3),
        1 => %InventoryItem{nameid: 1_010, amount: 1}
      }
    }

  defp weapon(id, nameid, attrs \\ []),
    do: struct!(%InventoryItem{id: id, nameid: nameid, amount: 1, identify: 1}, attrs)
end
