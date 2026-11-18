defmodule Aesir.ZoneServer.Unit.Pet.EvolutionHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.PetEvolveCommand
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  # Only renewal data has evolutions: Poring evolves into Mastering with 10
  # Yggdrasil Leaves and 3 Unripe Apples.
  @moduletag game_mode: :renewal

  @map "pet_evolution_map"
  @poring 1002
  @mastering 1090
  @poring_egg 9001
  @mastering_egg 9069
  @leaf 610
  @apple 619
  @red_potion 501
  @backpack 10_013

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})
    suffix = System.unique_integer([:positive])
    name = "peh#{suffix}"

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
          name: "Peh#{suffix}",
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

    %{session: spawned(account, character) |> with_pet(intimate: 1000)}
  end

  test "each failure answers its code and changes nothing", %{session: loyal} do
    ready = with_items(loyal, [{@leaf, [10]}, {@apple, [3]}])

    for {session, egg, feature?, error} <- [
          {ready, @red_potion, true, :PET_ERROR_EVOLUTION_FAIL_NOT_PETEGG},
          {%{ready | pet: nil}, @mastering_egg, true, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN},
          {ready, @mastering_egg, false, :PET_ERROR_EVOLUTION_FAIL_UNKNOWN},
          {with_pet(ready, intimate: 909), @mastering_egg, true,
           :PET_ERROR_EVOLUTION_FAIL_RG_FAMILIAR},
          {with_pet(ready, equip: @backpack), @mastering_egg, true,
           :PET_ERROR_EVOLUTION_FAIL_RG_FAMILIAR},
          {ready, @poring_egg, true, :PET_ERROR_EVOLUTION_FAIL_NOTEXIST_CALLPET},
          {with_items(loyal, [{@leaf, [9]}, {@apple, [3]}]), @mastering_egg, true,
           :PET_ERROR_EVOLUTION_FAIL_MATERIAL}
        ] do
      stub(Config, :feature_pet_evolution?, fn -> feature? end)

      assert {:noreply, ^session} = evolve(session, egg)

      assert_receive {:send, _,
                      {:pet_result, %PetResult{request_id: 1, success: false, error: ^error}}}
    end

    assert %Pet{class: @poring, egg_id: @poring_egg} = Repo.get!(Pet, loyal.pet.pet_id)
  end

  test "a Loyal Poring with the materials becomes a Mastering", %{session: session} do
    session = with_items(session, [{@leaf, [10]}, {@apple, [3]}])
    {egg_index, _egg} = egg_slot(session)
    {:ok, mastering} = Catalog.by_mob(@mastering)

    assert {:noreply, evolved} = evolve(session, @mastering_egg)

    assert %PetState{
             class_id: @mastering,
             mob_db_id: @poring,
             egg_id: @mastering_egg,
             name: "Mastering",
             world_gid: gid
           } = evolved.pet

    assert gid == session.pet.world_gid
    assert evolved.pet.intimate == mastering.intimacy_start
    assert Inventory.held_amount(evolved.game_state.inventory, @leaf) == 0
    assert Inventory.held_amount(evolved.game_state.inventory, @apple) == 0
    assert {^egg_index, %InventoryItem{nameid: @mastering_egg} = egg} = egg_slot(evolved)
    assert Egg.hatched?(egg)
    assert Repo.get!(InventoryItem, egg.id).nameid == @mastering_egg

    assert %Pet{class: @mastering, egg_id: @mastering_egg, name: "Mastering"} =
             row = Repo.get!(Pet, session.pet.pet_id)

    assert row.intimate == mastering.intimacy_start
    assert {:ok, _position} = SpatialIndex.get_unit_position(:pet, gid)

    assert_receive {:send, _,
                    {:pet_result, %PetResult{success: true, error: :PET_ERROR_EVOLUTION_SUCCESS}}}
  end

  test "a renamed pet keeps its name", %{session: session} do
    session =
      session
      |> with_pet(name: "Buddy", rename_flag: 1)
      |> with_items([{@leaf, [10]}, {@apple, [3]}])

    assert {:noreply, evolved} = evolve(session, @mastering_egg)

    assert %PetState{class_id: @mastering, name: "Buddy"} = evolved.pet
    assert Repo.get!(Pet, session.pet.pet_id).name == "Buddy"
  end

  test "each matching stack loses up to the full requirement until exactly none is owed",
       %{session: session} do
    session = with_items(session, [{@leaf, [6, 6, 6]}, {@apple, [3, 2]}])

    assert {:noreply, evolved} = evolve(session, @mastering_egg)

    assert %PetState{class_id: @mastering} = evolved.pet
    assert Inventory.held_amount(evolved.game_state.inventory, @leaf) == 0

    assert [%InventoryItem{amount: 2}] =
             for({_index, %{nameid: @apple} = item} <- evolved.game_state.inventory, do: item)
  end

  test "with the egg gone the materials are spent and nothing evolves", %{session: session} do
    session = session |> with_items([{@leaf, [10]}, {@apple, [3]}]) |> without_egg()

    assert {:noreply, failed} = evolve(session, @mastering_egg)

    assert %PetState{class_id: @poring} = failed.pet
    assert Inventory.held_amount(failed.game_state.inventory, @leaf) == 0
    assert Inventory.held_amount(failed.game_state.inventory, @apple) == 0
    assert Repo.get!(Pet, session.pet.pet_id).class == @poring

    assert_receive {:send, _,
                    {:pet_result,
                     %PetResult{
                       success: false,
                       error: :PET_ERROR_EVOLUTION_FAIL_NOTEXIST_CALLPET
                     }}}
  end

  defp evolve(session, egg_item_id) do
    CommandHandler.request(
      %PetRequest{request_id: 1, command: {:evolve, %PetEvolveCommand{egg_item_id: egg_item_id}}},
      session
    )
  end

  defp with_pet(%SessionState{pet: pet} = session, fields) do
    Repo.update_all(from(p in Pet, where: p.id == ^pet.pet_id), set: fields)
    %{session | pet: struct!(pet, fields)}
  end

  defp with_items(%SessionState{game_state: owner} = session, stacks) do
    inventory =
      for {item_id, amounts} <- stacks, amount <- amounts, reduce: owner.inventory do
        inventory ->
          index = Enum.max(Map.keys(inventory), fn -> -1 end) + 1
          item = %InventoryItem{nameid: item_id, amount: amount, identify: 1}
          change = {:added, index, item}

          {:ok, inventory} =
            InventoryOps.persist_change(
              owner.character_id,
              inventory,
              Map.put(inventory, index, item),
              change
            )

          inventory
      end

    %{session | game_state: %{owner | inventory: inventory}}
  end

  defp without_egg(%SessionState{game_state: owner} = session) do
    {index, egg} = egg_slot(session)
    Repo.delete!(egg)
    %{session | game_state: %{owner | inventory: Map.delete(owner.inventory, index)}}
  end

  defp egg_slot(%SessionState{pet: pet, game_state: owner}),
    do: Enum.find(owner.inventory, fn {_index, item} -> Egg.pet_id(item) == pet.pet_id end)

  defp spawned(account, character) do
    {:ok, definition} = Catalog.by_mob(@poring)

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
        stats: PlayerState.new(character).stats
      },
      connection_pid: self(),
      pet_runtime: %Runtime{generation: 3}
    }

    session |> LifecycleHandler.restore(character) |> LifecycleHandler.spawned_after_map_load()
  end
end
