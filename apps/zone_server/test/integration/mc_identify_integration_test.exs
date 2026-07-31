defmodule Aesir.ZoneServer.Integration.McIdentifyIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.LearnSkill
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillList
  alias Aesir.Net.SkillMenu
  alias Aesir.Net.SkillMenuReply
  alias Aesir.Repo
  @item_id 1101

  test "selects one of two unidentified rows with the same item id and persists it" do
    character = insert_character()
    first = insert_item(character.id)
    second = insert_item(character.id)

    session =
      start_player_session(character: character, map_name: "prontera", position: {150, 150})

    on_exit(fn -> end_player_session(session) end)
    flush_packets()

    simulate_incoming_message(session.pid, %LearnSkill{skill_id: 40})
    assert_receive {:packet_sent, %SkillList{}, _}, 1_000
    flush_packets()

    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: 40,
      level: 1,
      target_id: character.id
    })

    assert_receive {:packet_sent,
                    %SkillMenu{src_skill_id: 40, kind: :INVENTORY_SLOTS, entry_ids: slots}, _},
                   1_000

    assert length(slots) == 2
    selected_slot = List.last(slots)
    selected_id = get_player_state(session.pid).inventory[selected_slot].id

    simulate_incoming_message(session.pid, %SkillMenuReply{
      src_skill_id: 40,
      selected_id: selected_slot
    })

    assert get_player_state(session.pid).inventory[selected_slot].identify == 1

    assert Repo.get!(InventoryItem, selected_id).identify == 1
    other_id = if selected_id == first.id, do: second.id, else: first.id
    assert Repo.get!(InventoryItem, other_id).identify == 0
  end

  defp insert_character do
    uniq = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "identifier#{uniq}",
        userid: "identifier#{uniq}",
        user_pass: "password",
        email: "identifier#{uniq}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Identifier#{uniq}",
      class: 5,
      base_level: 20,
      job_level: 20,
      skill_point: 1,
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      save_map: "prontera",
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end

  defp insert_item(character_id) do
    %InventoryItem{}
    |> InventoryItem.changeset(%{
      char_id: character_id,
      nameid: @item_id,
      amount: 1,
      identify: 0
    })
    |> Repo.insert!()
  end
end
