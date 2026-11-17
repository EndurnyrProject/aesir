defmodule Aesir.ZoneServer.Unit.Pet.LifecycleHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.ChatNotice
  alias Aesir.Net.PetMenuCommand
  alias Aesir.Net.PetPrivateState
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Pet.Handlers.CommandHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.PetState
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "pet_life_map"
  @other_map "pet_life_dest"

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    for map <- [@map, @other_map] do
      :ets.insert(EtsTable.table_for(:map_cache), {map, MapData.new(map, 60, 60)})
    end

    suffix = System.unique_integer([:positive])
    username = "plc#{suffix}"

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: username,
          userid: username,
          user_pass: "password",
          email: "#{username}@example.com"
        })
      )

    character =
      Repo.insert!(
        Character.changeset(%Character{}, %{
          account_id: account.id,
          char_num: 0,
          name: "Plc#{suffix}",
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
    %{account: account, character: character, definition: definition}
  end

  describe "restore/2" do
    test "restore clears a dangling pet_id", %{character: character} do
      character = link(character, 999_999)

      session = LifecycleHandler.restore(session(character, %{}), character)

      assert session.pet == nil
      assert Repo.get!(Character, character.id).pet_id == 0
    end

    test "a hatched row owned by another character is left alone and unlinked", ctx do
      {inventory, pet} = hatched(ctx)
      Repo.update_all(from(p in Pet, where: p.id == ^pet.id), set: [char_id: 1])
      character = Repo.get!(Character, ctx.character.id)

      session = LifecycleHandler.restore(session(character, inventory), character)

      assert session.pet == nil
      assert Repo.get!(Character, character.id).pet_id == 0
      assert %Pet{incubate: 0, char_id: 1} = Repo.get!(Pet, pet.id)
    end

    test "a row still in its egg hides the egg and unlinks it", ctx do
      {:ok, inventory, pet} = create(ctx)
      character = link(ctx.character, pet.id)

      session = LifecycleHandler.restore(session(character, inventory), character)

      assert session.pet == nil
      assert Repo.get!(Character, character.id).pet_id == 0
      assert {:ok, %{attribute: 1} = egg} = Egg.find(session.game_state.inventory, pet.id)
      assert Repo.get!(InventoryItem, egg.id).attribute == 1
      assert Repo.get!(Pet, pet.id).incubate == 1
    end

    test "a hatched pet is restored off the map and spawns after the map loads", ctx do
      {inventory, pet} = hatched(ctx)
      Repo.update_all(from(p in Pet, where: p.id == ^pet.id), set: [name: "Custom"])
      character = Repo.get!(Character, ctx.character.id)

      restored = LifecycleHandler.restore(session(character, inventory), character)

      assert %PetState{pet_id: pet_id, name: "Poring", world_gid: gid, map_name: @map} =
               restored.pet

      assert pet_id == pet.id
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, gid)

      spawned = LifecycleHandler.spawned_after_map_load(restored)

      assert {:ok, {PetState, %PetState{world_gid: ^gid}, _pid}} =
               UnitRegistry.get_unit(:pet, gid)

      assert is_reference(spawned.pet_runtime.ai_timer_ref)

      assert_receive {:send, _,
                      {:pet_state_change, %PetStateChange{gid: ^gid, type: :PET_STATE_INIT}}}

      assert_receive {:send, _, {:pet_private_state, %PetPrivateState{gid: ^gid, intimacy: 250}}}
    end
  end

  describe "spawned_after_map_load/1" do
    test "on a GvG map with pet_disable_in_gvg the pet returns to its egg", ctx do
      stub(Config, :pet_disable_in_gvg?, fn -> true end)
      stub(MapFlags, :gvg?, fn @map -> true end)
      session = restored(ctx)
      gid = session.pet.world_gid

      returned = LifecycleHandler.spawned_after_map_load(session)

      assert returned.pet == nil
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, gid)
      assert Repo.get!(Pet, session.pet.pet_id).incubate == 1

      assert_receive {:send, _,
                      {:chat_notice,
                       %ChatNotice{kind: :INFO, text: "Pets are not allowed in Guild Wars."}}}
    end
  end

  describe "detach_for_warp/2" do
    test "the pet leaves with its owner and re-enters at the destination", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      gid = session.pet.world_gid

      detached = LifecycleHandler.detach_for_warp(session, {@other_map, 30, 31})

      assert %PetState{world_gid: ^gid, map_name: @other_map, x: 30, y: 31} = detached.pet
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, gid)
      assert {:error, :not_found} = SpatialIndex.get_unit_position(:pet, gid)
      assert detached.pet_runtime.ai_timer_ref == nil

      owner = %{detached.game_state | map_name: @other_map, x: 30, y: 31}
      entered = LifecycleHandler.spawned_after_map_load(%{detached | game_state: owner})

      assert {:ok, {30, 31, @other_map}} = SpatialIndex.get_unit_position(:pet, gid)
      assert entered.pet.world_gid == gid
    end
  end

  describe "return_to_egg/1" do
    test "with the egg missing the pet stays out", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      session = %{session | game_state: %{session.game_state | inventory: %{}}}

      assert LifecycleHandler.return_to_egg(session) == session
    end

    test "puts the pet back in its egg and takes it out of the world", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      %PetState{world_gid: gid, pet_id: pet_id} = session.pet
      session = %{session | pet: %{session.pet | hungry: 33}}

      returned = LifecycleHandler.return_to_egg(session)

      assert returned.pet == nil
      assert returned.pet_runtime.generation == session.pet_runtime.generation + 1
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, gid)
      assert {:ok, %{attribute: 0}} = Egg.find(returned.game_state.inventory, pet_id)
      assert %Pet{incubate: 1, hungry: 33} = Repo.get!(Pet, pet_id)
      assert Repo.get!(Character, ctx.character.id).pet_id == 0

      assert_receive {:send, _,
                      {:pet_state_change,
                       %PetStateChange{gid: ^gid, type: :PET_STATE_UPDATE_EGG, value: 1}}}
    end
  end

  describe "menu requests" do
    test "status sends the private state and return-to-egg returns the pet", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      gid = session.pet.world_gid
      flush_sent()

      assert {:noreply, ^session} = CommandHandler.request(menu(1, :PET_MENU_STATUS), session)
      assert_receive {:send, _, {:pet_private_state, %PetPrivateState{gid: ^gid}}}
      assert_receive {:send, _, {:pet_result, %PetResult{request_id: 1, success: true}}}

      assert {:noreply, returned} =
               CommandHandler.request(menu(2, :PET_MENU_RETURN_TO_EGG), session)

      assert returned.pet == nil
      assert_receive {:send, _, {:pet_result, %PetResult{request_id: 2, success: true}}}
    end

    test "a run-away pet ignores the menu", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      session = %{session | pet: %{session.pet | intimate: 0}}
      flush_sent()

      assert {:noreply, ^session} = CommandHandler.request(menu(3, :PET_MENU_STATUS), session)
      refute_received {:send, _, {:pet_private_state, _}}
      assert_receive {:send, _, {:pet_result, %PetResult{request_id: 3, success: false}}}
    end
  end

  describe "terminate/1" do
    test "saves a pet with intimacy and deletes a run-away pet", ctx do
      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      pet_id = session.pet.pet_id

      assert :ok = LifecycleHandler.terminate(%{session | pet: %{session.pet | hungry: 33}})
      assert %Pet{hungry: 33, incubate: 0} = Repo.get!(Pet, pet_id)
      assert {:error, :not_found} = UnitRegistry.get_unit(:pet, session.pet.world_gid)

      session = ctx |> restored() |> LifecycleHandler.spawned_after_map_load()
      run_away_id = session.pet.pet_id

      assert :ok = LifecycleHandler.terminate(%{session | pet: %{session.pet | intimate: 0}})
      refute Repo.get(Pet, run_away_id)
      assert Repo.get!(Character, ctx.character.id).pet_id == 0
    end
  end

  defp create(ctx) do
    Persistence.create_with_egg(
      ctx.account.id,
      ctx.character.id,
      ctx.definition,
      %{level: 1, name: "Poring"},
      %{},
      :infinity
    )
  end

  defp hatched(ctx) do
    {:ok, inventory, pet} = create(ctx)
    {:ok, inventory, pet} = Persistence.hatch(pet, ctx.account.id, ctx.character.id, inventory)
    {inventory, pet}
  end

  defp restored(ctx) do
    {inventory, _pet} = hatched(ctx)
    character = Repo.get!(Character, ctx.character.id)
    LifecycleHandler.restore(session(character, inventory), character)
  end

  defp link(character, pet_id) do
    Repo.update_all(from(c in Character, where: c.id == ^character.id), set: [pet_id: pet_id])
    Repo.get!(Character, character.id)
  end

  defp menu(id, action),
    do: %PetRequest{request_id: id, command: {:menu, %PetMenuCommand{action: action}}}

  defp flush_sent do
    receive do
      {:send, _, _} -> flush_sent()
    after
      0 -> :ok
    end
  end

  defp session(character, inventory) do
    %SessionState{
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
  end
end
