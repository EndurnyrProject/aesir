defmodule Aesir.ZoneServer.Mmo.Refine.WeaponSkillTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.ZoneServer.Factory

  alias Aesir.Factory, as: DbFactory
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase
  alias Aesir.ZoneServer.Mmo.Refine.WeaponSkill
  alias Aesir.ZoneServer.Mmo.Refine.WeaponSkill.Context

  setup :set_mimic_from_context

  setup do
    definitions =
      Map.new(1..5, fn level ->
        id = 9_000 + level

        {id,
         build(:item_definition, id: id, type: :weapon, weapon_level: level, refineable: true)}
      end)

    definitions =
      Map.put(definitions, 9_010, %{definitions[9_001] | id: 9_010, refineable: false})

    stub(Items, :by_id, &Map.fetch(definitions, &1))

    stub(RefineDatabase, :level_info, fn
      :weapon, 1, 4 ->
        build(:refine_level,
          chances: %{normal: build(:refine_chance, rate: 6755, material_nameid: 1010)}
        )

      _, _, _ ->
        nil
    end)

    :ok
  end

  test "offer_uses_identified_unworn_weapons_and_held_ore" do
    state =
      build(:player_state,
        inventory: %{
          0 => DbFactory.build(:inventory_item, id: 10, nameid: 9001, refine: 3),
          1 => DbFactory.build(:inventory_item, id: 11, nameid: 9010),
          2 => DbFactory.build(:inventory_item, id: 12, nameid: 9001, equip: 2),
          3 => DbFactory.build(:inventory_item, id: 13, nameid: 9001, equip: 32),
          4 => DbFactory.build(:inventory_item, id: 14, nameid: 9001, identify: 0),
          5 => DbFactory.build(:inventory_item, id: 15, nameid: 9001, refine: 4),
          6 => DbFactory.build(:inventory_item, id: 16, nameid: 9002),
          7 => DbFactory.build(:inventory_item, id: 17, nameid: 9003),
          8 => DbFactory.build(:inventory_item, id: 18, nameid: 9004),
          9 => DbFactory.build(:inventory_item, id: 19, nameid: 9005),
          10 => DbFactory.build(:inventory_item, nameid: 1010),
          11 => DbFactory.build(:inventory_item, nameid: 984),
          12 =>
            DbFactory.build(:inventory_item,
              id: 22,
              nameid: 9001,
              attribute: 1,
              bound: 4,
              expire_time: ~N[2020-01-01 00:00:00]
            )
        }
      )

    assert WeaponSkill.offer(state, 4) == %{0 => 10, 1 => 11, 7 => 17, 8 => 18, 12 => 22}
    assert WeaponSkill.offer(state, 0) == %{}
    assert WeaponSkill.material(1) == {:ok, 1_010}
    assert WeaponSkill.material(2) == {:ok, 1_011}
    assert WeaponSkill.material(3) == {:ok, 984}
    assert WeaponSkill.material(4) == {:ok, 984}
    assert WeaponSkill.material(5) == :error
  end

  describe "prepare/4" do
    setup do
      weapon = DbFactory.build(:inventory_item, id: 10, nameid: 9001, refine: 3)
      ore = DbFactory.build(:inventory_item, nameid: 1010)
      %{state: build(:player_state, inventory: %{0 => weapon, 1 => ore})}
    end

    test "reply preparation revalidates the selected row and process", %{state: state} do
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
      stub(RefineDatabase, :level_info, fn _, _, _ -> build(:refine_level) end)
      assert {:error, :not_refinable} = WeaponSkill.prepare(state, 0, 10, 4)

      stub(RefineDatabase, :level_info, fn _, _, _ ->
        build(:refine_level,
          chances: %{normal: build(:refine_chance, rate: 9999, material_nameid: 984)}
        )
      end)

      assert {:error, :not_refinable} = WeaponSkill.prepare(state, 0, 10, 4)
    end

    test "reads the next refine level without repeating offer filters", %{state: state} do
      selected = %{state.inventory[0] | equip: 2, identify: 0}
      state = %{state | inventory: Map.put(state.inventory, 0, selected)}

      assert {:ok,
              %Context{item: ^selected, definition: %{id: 9001}, normal_rate: 6755, ore_index: 1}} =
               WeaponSkill.prepare(state, 0, 10, 4)
    end
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
end
