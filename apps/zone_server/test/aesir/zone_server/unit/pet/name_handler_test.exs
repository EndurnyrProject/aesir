defmodule Aesir.ZoneServer.Unit.Pet.NameHandlerTest do
  use Aesir.DataCase, async: true
  import Aesir.TestEtsSetup
  import Mimic
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet

  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetEmotion
  alias Aesir.Net.PetEmotionCommand
  alias Aesir.Net.PetPrivateState
  alias Aesir.Net.PetRenameCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.UnitSpawn

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  import Bitwise
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry
  @map "pet_accessory_map"
  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    suffix = System.unique_integer([:positive])
    name = "pah#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: name,
          userid: name,
          user_pass: "password",
          email: "#{name}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Pah#{suffix}",
          class: 1,
          base_level: 1,
          str: 1,
          agi: 1,
          vit: 1,
          int: 1,
          dex: 1,
          luk: 1
        })
      )

    {:ok, definition} = Catalog.by_mob(1002)
    session = spawned(account, character, definition)
    observer = %{session.game_state | character_id: character.id + 1_000_000}
    UnitRegistry.register_player(observer, self())
    SpatialIndex.add_player(observer.character_id, session.pet.x, session.pet.y, @map)
    %{session: session}
  end

  test "rename persists the pet and egg and informs observers", %{session: session} do
    request = %PetRequest{
      request_id: 1,
      command: {:rename, %PetRenameCommand{name: "  New  Name "}}
    }

    assert {:noreply, renamed} = CommandHandler.request(request, session)
    assert renamed.pet.name == "New Name"
    assert renamed.pet.rename_flag == 1
    assert {:ok, egg} = Egg.find(renamed.game_state.inventory, renamed.pet.pet_id)
    assert (egg.card3 &&& 1) == 1
    assert Repo.get!(Pet, renamed.pet.pet_id).name == "New Name"
    assert_receive {:"$gen_cast", {:send_packet, %UnitSpawn{name: "New Name"}}}
    assert_receive {:send, _, {:pet_result, %PetResult{success: true}}}
  end

  test "long names are limited before space normalization", %{session: session} do
    assert {:noreply, renamed} =
             CommandHandler.request(rename("abcdefghijklmnopqrstuvwx"), session)

    assert renamed.pet.name == "abcdefghijklmnopqrstuvw"
  end

  test "rename stops at the first NUL", %{session: session} do
    assert {:noreply, renamed} = CommandHandler.request(rename("Pet\0ignored"), session)
    assert renamed.pet.name == "Pet"
    assert Repo.get!(Pet, renamed.pet.pet_id).name == "Pet"
  end

  test "control bytes after the 24-byte scan are ignored", %{session: session} do
    assert {:noreply, renamed} =
             CommandHandler.request(rename("abcdefghijklmnopqrstuvwx\n"), session)

    assert renamed.pet.name == "abcdefghijklmnopqrstuvw"
  end

  test "rename truncation preserves complete UTF-8 characters", %{session: session} do
    assert {:noreply, renamed} =
             CommandHandler.request(rename("abcdefghijklmnopqrstuvé"), session)

    assert renamed.pet.name == "abcdefghijklmnopqrstuv"
    persisted = Repo.get!(Pet, renamed.pet.pet_id).name
    assert persisted == "abcdefghijklmnopqrstuv"
    assert String.valid?(persisted)
  end

  test "subsequent rename is silent unless the configuration permits it", %{session: session} do
    {:noreply, renamed} = CommandHandler.request(rename("First"), session)
    flush_packets()
    assert {:noreply, ^renamed} = CommandHandler.request(rename("Second"), renamed)

    assert_receive {:send, _,
                    {:pet_result, %PetResult{success: false, error: :PET_ERROR_INVALID_REQUEST}}}

    refute_received {:send, _, {:chat_notice, %ChatNotice{}}}
    refute_received {:send, _, {:pet_private_state, %PetPrivateState{}}}
    stub(Config, :pet_rename?, fn -> true end)
    assert {:noreply, changed} = CommandHandler.request(rename("Second"), renamed)
    assert changed.pet.name == "Second"
  end

  test "control bytes are silent but spaces receive the refusal and state", %{session: session} do
    flush_packets()
    assert {:noreply, ^session} = CommandHandler.request(rename("Bad\nName"), session)
    assert_receive {:send, _, {:pet_result, %PetResult{success: false}}}
    refute_received {:send, _, {:chat_notice, %ChatNotice{}}}
    refute_received {:send, _, {:pet_private_state, %PetPrivateState{}}}
    assert {:noreply, ^session} = CommandHandler.request(rename("   "), session)
    assert_receive {:send, _, {:chat_notice, %ChatNotice{text: "Invalid name."}}}
    assert_receive {:send, _, {:pet_private_state, %PetPrivateState{}}}
  end

  test "emotion reaches the area without an intimacy gate", %{session: session} do
    session = put_in(session.pet.intimate, 0)
    gid = session.pet.world_gid
    request = %PetRequest{request_id: 3, command: {:emotion, %PetEmotionCommand{data: 42}}}
    assert {:noreply, ^session} = CommandHandler.request(request, session)
    assert_receive {:"$gen_cast", {:send_packet, %PetEmotion{gid: ^gid, data: 42}}}
  end

  defp rename(name),
    do: %PetRequest{request_id: 2, command: {:rename, %PetRenameCommand{name: name}}}

  defp flush_packets do
    receive do
      _message -> flush_packets()
    after
      0 -> :ok
    end
  end

  defp spawned(account, character, definition) do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        account.id,
        character.id,
        definition,
        %{level: 1, name: "Pet"},
        %{},
        :infinity
      )

    {:ok, inventory, _pet} = Persistence.hatch(pet, account.id, character.id, inventory)
    character = Repo.get!(Character, character.id)

    session = %SessionState{
      game_state: %PlayerState{
        character_id: character.id,
        account_id: character.account_id,
        character_name: character.name,
        map_name: @map,
        x: 10,
        y: 10,
        dir: 0,
        walk_speed: 150,
        movement_state: :standing,
        view_range: 14,
        inventory: inventory,
        stats: Stats.from_character(character)
      },
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }

    session |> LifecycleHandler.restore(character) |> LifecycleHandler.spawned_after_map_load()
  end
end
