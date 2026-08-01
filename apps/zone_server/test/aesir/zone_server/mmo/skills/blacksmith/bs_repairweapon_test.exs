defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweaponTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillMenuReply
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweapon
  alias Aesir.ZoneServer.Unit.ItemContainer
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillMenuHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(PlayerSession)
    :ok
  end

  test "has a 2.5 second fixed cast, 30 SP cost, and range 2" do
    definition = definition()

    assert definition.cast_time == [2_500]
    assert definition.fixed_cast_time == [2_500]
    assert definition.sp_cost == [30]
    assert definition.range == 2
  end

  test "offers only broken rows with a repairable equipment level" do
    target =
      player(2, %{
        0 => item(1101, 1),
        1 => item(1110, 1),
        2 => item(1119, 1),
        3 => item(1100, 1),
        4 => item(2101, 1),
        5 => item(1341, 1),
        6 => item(15_282, 1),
        7 => item(1101, 0),
        8 => item(501, 1)
      })

    register(target)

    assert {:ok, offered} =
             BsRepairweapon.cast(player(1), {:unit, 2}, 1, definition())

    assert offered.pending_menu_offer == %{
             skill_id: 108,
             kind: :INVENTORY_SLOTS,
             entry_ids: [0, 1, 2, 3, 4],
             level: 1
           }

    assert offered.target_id == 2
  end

  test "takes the material required by each repairable equipment level from the caster" do
    stub(PlayerSession, :repair_item, fn _pid, 0 -> :ok end)

    for {equipment_id, material_id} <- [
          {1101, 1_002},
          {1110, 998},
          {1119, 999},
          {1100, 756},
          {2101, 999}
        ] do
      register(player(2, %{0 => item(equipment_id, 1)}))
      caster = %{player(1, %{9 => item(material_id, 0)}) | target_id: 2}

      assert {:ok, repaired} =
               BsRepairweapon.on_menu_reply(caster, %{id: 0, extras: []}, 1)

      assert ItemContainer.held_amount(repaired.inventory, material_id) == 0
      assert length(repaired.pending_inventory_persist) == 1
    end
  end

  test "does not call the target session when the caster lacks the material" do
    reject(&PlayerSession.repair_item/2)
    register(player(2, %{0 => item(1101, 1)}))
    caster = %{player(1) | target_id: 2}

    assert {:error, :no_materials} =
             BsRepairweapon.on_menu_reply(caster, %{id: 0, extras: []}, 1)
  end

  test "revalidates level 5 weapons and level 2 armor before calling the target session" do
    reject(&PlayerSession.repair_item/2)
    caster = %{player(1, %{9 => item(756, 0), 10 => item(999, 0)}) | target_id: 2}

    for item_id <- [1341, 15_282] do
      register(player(2, %{0 => item(item_id, 1)}))

      assert {:error, :unrepairable_item} =
               BsRepairweapon.on_menu_reply(caster, %{id: 0, extras: []}, 1)
    end
  end

  test "refuses a target that moved out of range while the menu was open" do
    reject(&PlayerSession.repair_item/2)
    target = %{player(2, %{0 => item(1101, 1)}) | x: 13}
    register(target)
    caster = %{player(1, %{9 => item(1_002, 0)}) | target_id: 2}

    assert {:error, :target_out_of_range} =
             BsRepairweapon.on_menu_reply(caster, %{id: 0, extras: []}, 1)
  end

  test "a stale menu keeps the material and tells the caster the repair failed" do
    test_pid = self()
    expect(PlayerSession, :repair_item, fn _pid, 3 -> {:error, :repair_failed} end)

    expect(PlayerSession, :send_packet, fn _pid, %SkillCastFailed{} = packet ->
      send(test_pid, {:failure_sent, packet})
      :ok
    end)

    register(player(2, %{3 => item(1101, 1)}))
    caster = %{player(1, %{9 => item(1_002, 0)}) | target_id: 2}
    register(caster)

    state = %{
      game_state: caster,
      connection_pid: self(),
      pending_skill_menu: %{
        skill_id: 108,
        kind: :INVENTORY_SLOTS,
        entry_ids: [3],
        level: 1
      }
    }

    assert {:noreply, repaired} =
             SkillMenuHandler.handle_reply(
               %SkillMenuReply{src_skill_id: 108, selected_id: 3},
               state
             )

    assert ItemContainer.held_amount(repaired.game_state.inventory, 1_002) == 1
    assert repaired.game_state.pending_inventory_persist == []
    assert_receive {:failure_sent, %SkillCastFailed{skill_id: 108}}
  end

  defp definition do
    {:ok, definition} = Catalog.by_id(108)
    definition
  end

  defp player(id, inventory \\ %{}) do
    %PlayerState{
      character_id: id,
      inventory: inventory,
      map_name: "repair_test",
      x: 10,
      y: 10,
      pending_inventory_persist: []
    }
  end

  defp item(nameid, attribute, amount \\ 1) do
    %InventoryItem{nameid: nameid, amount: amount, attribute: attribute, equip: 0}
  end

  defp register(%PlayerState{} = state) do
    UnitRegistry.register_unit(:player, state.character_id, PlayerState, state, self())
  end
end
