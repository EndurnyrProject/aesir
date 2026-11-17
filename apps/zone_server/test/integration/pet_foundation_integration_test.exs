defmodule Aesir.ZoneServer.Integration.PetFoundationIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.MapLoaded
  alias Aesir.Net.MoveRequest
  alias Aesir.Net.PetCatchResult
  alias Aesir.Net.PetCatchStart
  alias Aesir.Net.PetCatchTargetCommand
  alias Aesir.Net.PetEggList
  alias Aesir.Net.PetRequest
  alias Aesir.Net.PetResult
  alias Aesir.Net.PetSelectEggCommand
  alias Aesir.Net.TradeAddItem
  alias Aesir.Net.TradeLock
  alias Aesir.Net.TradeOfferUpdate
  alias Aesir.Net.TradeRequest
  alias Aesir.Net.TradeRequestReceived
  alias Aesir.Net.TradeResponse
  alias Aesir.Net.UseItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Pet.PetState

  @map "pet_foundation_e2e"
  @warp_map "pet_foundation_warp_e2e"
  @poring 1_002
  @unripe_apple 619
  @incubator 643

  setup {Aesir.MimicMode, :global}

  setup do
    put_map(@map)
    put_map(@warp_map)
    start_per_test_map(@map)
    start_per_test_map(@warp_map)

    {:ok, definition} = Catalog.by_mob(@poring)
    %{definition: definition}
  end

  test "catch, hatch, follow, warp and relog keep one pet", %{definition: definition} do
    # Scaling the capture rate past the 10,000 roll base pins the catch roll.
    stub(Config, :pet_catch_rate, fn -> 10_000 end)

    character = character_fixture("PetE2E")
    seed_item(character.id, @unripe_apple)
    seed_item(character.id, @incubator)
    owner = start(character, @map, {50, 50})
    mob = start_mob_session(mob_id: @poring, map_name: @map, position: {52, 50})

    simulate_incoming_message(owner.pid, %UseItem{index: client_index(owner.pid, @unripe_apple)})
    assert_receive {:packet_sent, %PetCatchStart{}, _}, 1_000

    request(owner.pid, 1, {:catch_target, %PetCatchTargetCommand{target_id: mob.unit_id}})
    assert_receive {:packet_sent, %PetResult{request_id: 1, success: true}, _}, 1_000
    assert_receive {:packet_sent, %PetCatchResult{success: true}, _}, 1_000
    assert {:error, :not_found} = UnitRegistry.get_unit(:mob, mob.unit_id)

    egg = held_egg(owner.pid, definition.egg_item_id)
    pet_id = Egg.pet_id(egg)
    assert %Pet{incubate: 1, hungry: 100} = caught = Repo.get!(Pet, pet_id)
    assert caught.intimate == definition.intimacy_start

    flush_packets()
    simulate_incoming_message(owner.pid, %UseItem{index: client_index(owner.pid, @incubator)})
    assert_receive {:packet_sent, %PetEggList{indexes: [egg_index]}, _}, 1_000
    assert egg_index == client_index(owner.pid, definition.egg_item_id)

    request(owner.pid, 2, {:select_egg, %PetSelectEggCommand{index: egg_index}})
    assert_receive {:packet_sent, %PetResult{request_id: 2, success: true}, _}, 1_000

    hatched = PlayerSession.get_state(owner.pid)
    assert %PetState{pet_id: ^pet_id, map_name: @map} = hatched.pet
    assert Egg.hatched?(held_egg(owner.pid, definition.egg_item_id))
    assert %Pet{incubate: 0} = Repo.get!(Pet, pet_id)
    assert Repo.get!(Character, character.id).pet_id == pet_id
    assert_one_pet(owner.pid, @map)

    simulate_incoming_message(owner.pid, %MoveRequest{dest_x: 60, dest_y: 50})

    followed =
      eventually_pet(owner.pid, fn pet, owner_state ->
        owner_state.x == 60 and owner_state.y == 50 and
          Geometry.chebyshev_distance(pet.x, pet.y, 60, 50) <= 3
      end)

    assert {followed.x, followed.y} != {hatched.pet.x, hatched.pet.y}

    PlayerSession.warp(owner.pid, @warp_map, 40, 40)
    simulate_incoming_message(owner.pid, %MapLoaded{})
    eventually_pet(owner.pid, fn pet, _owner -> pet.map_name == @warp_map end)
    assert_one_pet(owner.pid, @warp_map)

    :ok = PlayerSession.disconnect(owner.pid)
    assert UnitRegistry.count_units_by_type(:pet) == 0
    assert %Pet{incubate: 0} = Repo.get!(Pet, pet_id)

    relogged = start(Repo.reload!(character), @warp_map, {40, 40})
    restored = eventually_pet(relogged.pid, fn pet, _owner -> pet.pet_id == pet_id end)
    assert restored.map_name == @warp_map
    assert_one_pet(relogged.pid, @warp_map)
  end

  test "a scripted getitem egg hatches and the hatched egg cannot be traded",
       %{definition: definition} do
    character = character_fixture("PetGet")
    seed_item(character.id, @incubator)
    owner = start(character, @map, {50, 50})
    partner = start(character_fixture("PetMate"), @map, {51, 50})

    owner.pid |> npc_ctx() |> Dsl.give_item(definition.egg_item_id, 1)

    egg = held_egg(owner.pid, definition.egg_item_id)
    pet_id = Egg.pet_id(egg)
    assert %Pet{incubate: 1, class: @poring} = Repo.get!(Pet, pet_id)

    simulate_incoming_message(owner.pid, %UseItem{index: client_index(owner.pid, @incubator)})
    assert_receive {:packet_sent, %PetEggList{indexes: [egg_index]}, _}, 1_000
    request(owner.pid, 3, {:select_egg, %PetSelectEggCommand{index: egg_index}})
    assert_receive {:packet_sent, %PetResult{request_id: 3, success: true}, _}, 1_000
    assert %PetState{pet_id: ^pet_id} = PlayerSession.get_state(owner.pid).pet
    assert Egg.hatched?(held_egg(owner.pid, definition.egg_item_id))

    open_trade(owner, partner)
    flush_packets()

    simulate_incoming_message(owner.pid, %TradeAddItem{
      index: client_index(owner.pid, definition.egg_item_id),
      amount: 1
    })

    refute_receive {:packet_sent, %TradeOfferUpdate{}, _}, 100
    simulate_incoming_message(owner.pid, %TradeLock{})

    updates = collect_packets_of_type(TradeOfferUpdate, 100)
    assert length(updates) == 2
    assert Enum.all?(updates, &(&1.own == [] and &1.partner == []))
  end

  defp start(character, map_name, position) do
    session = start_player_session(character: character, map_name: map_name, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    flush_packets()
    session
  end

  defp request(pid, request_id, command) do
    simulate_incoming_message(pid, %PetRequest{request_id: request_id, command: command})
  end

  defp open_trade(requester, target) do
    simulate_incoming_message(requester.pid, %TradeRequest{target_gid: target.character.id})
    assert_receive {:packet_sent, %TradeRequestReceived{}, _}, 1_000
    simulate_incoming_message(target.pid, %TradeResponse{accept: true})

    assert_eventually(fn ->
      PlayerSession.get_state(requester.pid).trade != nil and
        PlayerSession.get_state(target.pid).trade != nil
    end)
  end

  defp npc_ctx(pid) do
    session = PlayerSession.get_state(pid)

    %Ctx{
      char_id: session.game_state.character_id,
      account_id: session.game_state.account_id,
      connection_pid: session.connection_pid,
      game_state: session.game_state,
      source: {:npc, :pet_foundation_e2e},
      session_pid: pid
    }
  end

  defp eventually_pet(pid, predicate) do
    assert_eventually(fn ->
      state = PlayerSession.get_state(pid)
      match?(%PetState{}, state.pet) and predicate.(state.pet, state.game_state)
    end)

    PlayerSession.get_state(pid).pet
  end

  defp assert_one_pet(pid, map_name) do
    %PetState{world_gid: gid} = PlayerSession.get_state(pid).pet
    assert UnitRegistry.count_units_by_type(:pet) == 1
    assert {:ok, {PetState, %PetState{world_gid: ^gid}, ^pid}} = UnitRegistry.get_unit(:pet, gid)
    assert {:ok, {_, _, ^map_name}} = SpatialIndex.get_unit_position(:pet, gid)
  end

  defp held_egg(pid, egg_item_id) do
    PlayerSession.get_state(pid).game_state.inventory
    |> Map.values()
    |> Enum.find(&(&1.nameid == egg_item_id))
  end

  defp client_index(pid, nameid) do
    {index, _item} =
      Enum.find(PlayerSession.get_state(pid).game_state.inventory, fn {_index, item} ->
        item.nameid == nameid
      end)

    index + 2
  end

  defp character_fixture(prefix) do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        userid: "pete2e#{suffix}",
        user_pass: "password",
        email: "pete2e#{suffix}@example.com"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "#{prefix}#{suffix}",
      class: 0,
      base_level: 10,
      job_level: 10,
      learned_skills: %{"1" => 9},
      last_map: @map,
      last_x: 50,
      last_y: 50
    })
    |> Repo.insert!()
  end

  defp seed_item(character_id, nameid) do
    {:ok, _} =
      InventoryPersistence.insert_item(character_id, %{nameid: nameid, amount: 1, identify: 1})
  end

  defp put_map(name) do
    :ets.insert(EtsTable.table_for(:map_cache), {name, MapData.new(name, 100, 100)})
  end
end
