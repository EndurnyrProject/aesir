defmodule Aesir.ZoneServer.Integration.ItemEligibilityEquipTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.EquipItem
  alias Aesir.Net.EquipResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @shield 2101
  @katana 1116
  @left_hand 32
  @both_hand 34

  test "a level rejection leaves conflicting equipment, persistence, and stats untouched" do
    character = insert_character(:swordman, 1, "M")
    shield = seed_item(character.id, @shield, @left_hand)
    katana = seed_item(character.id, @katana, 0)
    session = start_session(character)
    before = PlayerSession.get_state(session.pid).game_state

    request_equip(session.pid, katana.id, @both_hand)

    assert %EquipResult{result: 1} = assert_packet_sent(EquipResult)
    after_rejection = PlayerSession.get_state(session.pid).game_state
    assert after_rejection.inventory == before.inventory
    assert after_rejection.stats == before.stats
    assert persisted_equip(shield.id) == @left_hand
    assert persisted_equip(katana.id) == 0
  end

  test "a job rejection uses the generic result and performs no conflict writes" do
    character = insert_character(:novice, 99, "M")
    shield = seed_item(character.id, @shield, @left_hand)
    katana = seed_item(character.id, @katana, 0)
    session = start_session(character)
    before = PlayerSession.get_state(session.pid).game_state

    request_equip(session.pid, katana.id, @both_hand)

    assert %EquipResult{result: 2} = assert_packet_sent(EquipResult)
    after_rejection = PlayerSession.get_state(session.pid).game_state
    assert after_rejection.inventory == before.inventory
    assert after_rejection.stats == before.stats
    assert persisted_equip(shield.id) == @left_hand
    assert persisted_equip(katana.id) == 0
  end

  defp insert_character(job, base_level, sex) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "elig#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: sex,
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, job_id} = AvailableJobs.job_name_to_id(job)

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Eligibility#{unique}",
        class: job_id,
        sex: sex,
        base_level: base_level,
        job_level: 1,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp seed_item(character_id, item_id, equip) do
    {:ok, item} =
      Persistence.insert_item(character_id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: equip
      })

    item
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: "prontera")
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp request_equip(pid, row_id, position) do
    state = PlayerSession.get_state(pid).game_state

    index =
      Enum.find_value(state.inventory, fn {index, item} -> if item.id == row_id, do: index end)

    simulate_incoming_message(pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: position
    })
  end

  defp persisted_equip(row_id), do: Repo.get!(InventoryItem, row_id).equip
end
