defmodule Aesir.ZoneServer.Integration.ItemEligibilityUseTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemUseResult
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @awakening_potion 656

  test "a restricted real consumable is rejected through packet dispatch" do
    character = novice()

    {:ok, item} =
      Persistence.insert_item(character.id, %{
        nameid: @awakening_potion,
        amount: 2,
        identify: 1
      })

    session = start_player_session(character: character)
    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    {index, inventory_item} =
      Enum.find(PlayerSession.get_state(session.pid).game_state.inventory, fn {_index, entry} ->
        entry.id == item.id
      end)

    simulate_incoming_message(session.pid, %UseItem{index: PlayerState.client_index(index)})

    assert %ItemUseResult{index: result_index, ok: false, reason: 3} =
             assert_packet_sent(ItemUseResult)

    assert result_index == PlayerState.client_index(index)
    assert PlayerSession.get_state(session.pid).game_state.inventory[index] == inventory_item
    assert Repo.get!(InventoryItem, item.id).amount == 2
  end

  defp novice do
    unique = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "itemuse#{unique}",
        user_pass: "password",
        email: "itemuse#{unique}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "ItemUse#{unique}",
      class: 0,
      base_level: 1,
      job_level: 1,
      hp: 40,
      max_hp: 40,
      sp: 11,
      max_sp: 11,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
