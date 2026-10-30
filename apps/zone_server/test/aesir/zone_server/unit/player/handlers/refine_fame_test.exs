defmodule Aesir.ZoneServer.Unit.Player.Handlers.RefineFameTest do
  use Aesir.DataCase, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.RefineOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Persistence)

    account =
      Repo.insert!(%Account{userid: "refine-fame", user_pass: "unused", email: "fame@test.local"})

    character =
      Repo.insert!(%Character{
        account_id: account.id,
        char_num: 0,
        name: "RefineMaker",
        class: 10
      })

    %{
      player: %PlayerState{
        character_id: character.id,
        stats: Stats.from_character(character),
        zeny: 100_000
      }
    }
  end

  test "own forged script refinement landing on ten stages the weapon-level award", %{
    player: player
  } do
    {:ok, definition} = ItemManagement.get_item_by_id(1101)

    for {level, points} <- [{1, 1}, {2, 25}, {3, 1_000}], up <- [1, 3] do
      stub(ItemManagement, :get_item_by_id, fn 1101 ->
        {:ok, %{definition | weapon_level: level}}
      end)

      player = holding(player, 10 - up, ItemCraft.forged(:neutral, 0, player.character_id))
      assert {made, {:ok, 10}} = RefineOps.success(player, 0, 1101, up)
      assert made.fame == points

      assert made.pending_fame_awards == [
               %{category: :blacksmith, awarded_points: points, total_fame: points}
             ]

      assert Repo.get!(InventoryItem, player.inventory[0].id).refine == 10
    end
  end

  test "script refinement excludes wrong makers kinds levels and destinations", %{player: player} do
    {:ok, definition} = ItemManagement.get_item_by_id(1101)

    for {craft, type, level, before, up, result} <- [
          {ItemCraft.forged(:neutral, 0, player.character_id + 1), :weapon, 1, 9, 1, 10},
          {ItemCraft.signed(player.character_id), :weapon, 1, 9, 1, 10},
          {nil, :weapon, 1, 9, 1, 10},
          {ItemCraft.forged(:neutral, 0, player.character_id), :armor, 1, 9, 1, 10},
          {ItemCraft.forged(:neutral, 0, player.character_id), :weapon, 4, 9, 1, 10},
          {ItemCraft.forged(:neutral, 0, player.character_id), :weapon, 1, 9, 2, 11},
          {ItemCraft.forged(:neutral, 0, player.character_id), :weapon, 1, 20, 1, 20}
        ] do
      stub(ItemManagement, :get_item_by_id, fn 1101 ->
        {:ok, %{definition | type: type, weapon_level: level}}
      end)

      player = holding(player, before, craft)
      assert {made, {:ok, ^result}} = RefineOps.success(player, 0, 1101, up)
      assert made.fame == 0
      assert made.pending_fame_awards == []
    end

    stub(ItemManagement, :get_item_by_id, fn 1101 -> {:error, :item_not_found} end)
    player = holding(player, 9, ItemCraft.forged(:neutral, 0, player.character_id))
    assert {made, {:ok, 10}} = RefineOps.success(player, 0, 1101)
    assert made.pending_fame_awards == []
  end

  test "a failed script refine write stages no fame", %{player: player} do
    player = holding(player, 9, ItemCraft.forged(:neutral, 0, player.character_id))
    stub(Persistence, :update_item, fn _item, _attrs -> {:error, :forced_failure} end)
    assert {^player, {:error, :forced_failure}} = RefineOps.success(player, 0, 1101)
    assert Repo.get!(InventoryItem, player.inventory[0].id).refine == 9
  end

  test "generic refinement to ten grants no production fame", %{player: player} do
    player = holding(player, 9, ItemCraft.forged(:neutral, 0, player.character_id))
    ore = Repo.insert!(%InventoryItem{char_id: player.character_id, nameid: 1010, amount: 1})
    player = %{player | inventory: Map.put(player.inventory, 1, ore)}

    assert {made, {:ok, :success, 10}} =
             RefineOps.apply(player, 0, 1101, :normal, false, success_roll: 0)

    assert made.pending_fame_awards == []
    assert made.fame == 0
  end

  defp holding(player, refine, craft) do
    item =
      Repo.insert!(%InventoryItem{
        char_id: player.character_id,
        nameid: 1101,
        amount: 1,
        refine: refine,
        craft: if(craft, do: ItemCraft.to_map(craft))
      })

    %{player | inventory: %{0 => item}}
  end
end
