defmodule Aesir.ZoneServer.Integration.ItemEligibilityLoginTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.UnequipResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.StatusPersistence
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @knife 1201
  @nagan 1130
  @right_hand 2

  setup do
    Mimic.copy(Persistence)
    Mimic.copy(StatusPersistence)
    :ok
  end

  test "cleans persisted prohibited equipment before publishing the player" do
    character = insert_character(:novice)
    permitted = seed_item(character.id, @knife, 2)
    prohibited = seed_item(character.id, @nagan, 3)

    assert {:ok, pid} =
             PlayerSession.start_link(%{character: character, connection_pid: self()})

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    state = PlayerSession.get_state(pid)

    assert state.game_state.inventory[0] == Repo.get!(InventoryItem, permitted.id)
    assert state.game_state.inventory[0].equip == @right_hand
    assert state.game_state.inventory[0].amount == 2
    assert state.game_state.inventory[1] == Repo.get!(InventoryItem, prohibited.id)
    assert state.game_state.inventory[1].equip == 0
    assert state.game_state.inventory[1].amount == 3
    assert state.game_state.stats.equipment.right_hand == @knife
    assert state.game_state.stats.granted_skills[48] == nil

    assert {:ok, {_module, published, ^pid}} =
             UnitRegistry.get_unit(:player, character.id)

    assert published.inventory == state.game_state.inventory
    refute_packet_sent(UnequipResult)
  end

  test "missing equipped definitions prevent player publication" do
    character = insert_character(:novice)
    item = seed_item(character.id, 999_999, 1)
    reject(&StatusPersistence.restore_on_spawn/1)

    assert {:stop, {:missing_definition, 999_999}} =
             PlayerSession.init(%{character: character, connection_pid: self()})

    assert Repo.get!(InventoryItem, item.id).equip == @right_hand
    assert {:error, :not_found} = UnitRegistry.get_unit(:player, character.id)
    refute_receive :spawn_player
  end

  test "failed multi-row cleanup rolls back and prevents player publication" do
    character = insert_character(:novice)
    first = seed_item(character.id, @nagan, 1)
    second = seed_item(character.id, @nagan, 1, 32)
    second_id = second.id

    stub(Persistence, :update_item, fn
      %InventoryItem{id: ^second_id}, %{equip: 0} ->
        {:error, :later_row_failed}

      item, attrs ->
        Mimic.call_original(Persistence, :update_item, [item, attrs])
    end)

    reject(&StatusPersistence.restore_on_spawn/1)

    assert {:stop, :later_row_failed} =
             PlayerSession.init(%{character: character, connection_pid: self()})

    assert Repo.get!(InventoryItem, first.id).equip == @right_hand
    assert Repo.get!(InventoryItem, second.id).equip == 32
    assert {:error, :not_found} = UnitRegistry.get_unit(:player, character.id)
    refute_receive :spawn_player
    refute_packet_sent(UnequipResult)
  end

  defp insert_character(job) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "login#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
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
        sex: "M",
        base_level: 99,
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

  defp seed_item(character_id, item_id, amount, equip \\ @right_hand) do
    {:ok, item} =
      Persistence.insert_item(character_id, %{
        nameid: item_id,
        amount: amount,
        identify: 1,
        equip: equip
      })

    item
  end
end
