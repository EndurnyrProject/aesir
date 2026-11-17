defmodule Aesir.ZoneServer.Unit.Pet.HungerHandlerTest do
  use Aesir.DataCase, async: true

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.PetFoodResult
  alias Aesir.Net.PetStateChange
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.PetManagement.Catalog
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Pet.Clock
  alias Aesir.ZoneServer.Unit.Pet.Handlers.HungerHandler
  alias Aesir.ZoneServer.Unit.Pet.Handlers.LifecycleHandler
  alias Aesir.ZoneServer.Unit.Pet.Persistence
  alias Aesir.ZoneServer.Unit.Pet.Runtime
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @map "pet_hunger_map"
  @apple_juice 531

  setup :setup_ets_tables
  setup :set_mimic_private

  setup do
    :ets.insert(EtsTable.table_for(:map_cache), {@map, MapData.new(@map, 60, 60)})

    suffix = System.unique_integer([:positive])
    username = "phh#{suffix}"

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
          name: "Phh#{suffix}",
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

  describe "feed_delta/3" do
    test "overfed above 90, halved with a floor of 1 above 75, scaled by the friendly rate",
         %{definition: definition} do
      for {hungry, fed, rate, expected} <- [
            {91, 50, 100, definition.intimacy_overfed},
            {76, 50, 100, 25},
            {76, 1, 100, 1},
            {50, 50, 100, 50},
            {50, 50, 200, 100}
          ] do
        assert HungerHandler.feed_delta(%{definition | intimacy_fed: fed}, hungry, rate) ==
                 expected
      end
    end
  end

  describe "arm/1" do
    test "the first interval is the scaled hunger delay, 20 s while starving", ctx do
      stub(Config, :pet_hungry_delay_rate, fn -> 200 end)
      session = spawned(ctx)

      assert_timer(session, 2 * ctx.definition.hungry_delay_ms)
      assert_timer(HungerHandler.arm(session), 2 * ctx.definition.hungry_delay_ms)
      assert_timer(HungerHandler.arm(with_pet(session, hungry: 0)), 20_000)
    end

    test "a zero hunger delay still waits 1 ms", ctx do
      session = spawned(ctx)
      stub(Config, :pet_hungry_delay_rate, fn -> 0 end)

      stub(Clock, :arm, fn delay, :hunger_tick, _generation ->
        send(self(), {:armed, delay})
        make_ref()
      end)

      HungerHandler.arm(session)

      assert_received {:armed, 1}
    end
  end

  describe "tick/1" do
    test "starving clamps hunger at 0, costs intimacy and ticks every 20 s", ctx do
      session = ctx |> spawned() |> with_pet(hungry: ctx.definition.fullness - 1) |> armed()
      expected = 250 + ctx.definition.intimacy_hungry

      ticked = HungerHandler.tick(session)

      assert %{hungry: 0, intimate: ^expected} = ticked.pet
      assert %Pet{hungry: 0, intimate: ^expected} = Repo.get!(Pet, ticked.pet.pet_id)
      assert {:ok, egg} = Egg.find(ticked.game_state.inventory, ticked.pet.pet_id)
      assert egg.card3 == Egg.card3(0, expected)
      assert_timer(ticked, 20_000)
      assert_state_change(:PET_STATE_INTIMACY, expected)
      assert_state_change(:PET_STATE_HUNGER, 0)
    end

    test "a fed pet loses its fullness per hunger delay", ctx do
      session = ctx |> spawned() |> with_pet(hungry: 50) |> armed()
      expected = 50 - ctx.definition.fullness

      ticked = HungerHandler.tick(session)

      assert %{hungry: ^expected, intimate: 250} = ticked.pet
      assert Repo.get!(Pet, ticked.pet.pet_id).hungry == expected
      assert_timer(ticked, ctx.definition.hungry_delay_ms)
      assert_state_change(:PET_STATE_HUNGER, expected)
      refute_received {:send, _, {:pet_state_change, %PetStateChange{type: :PET_STATE_INTIMACY}}}
    end

    test "a pet that ran away stops its hunger timer", ctx do
      session = ctx |> spawned() |> with_pet(intimate: 0) |> armed()

      ticked = HungerHandler.tick(session)

      assert ticked.pet == session.pet
      assert ticked.pet_runtime.hunger_timer_ref == nil
      refute_received {:send, _, {:pet_state_change, _}}
    end

    test "autofeed feeds a pet at or below the autofeed rate", ctx do
      session = ctx |> spawned() |> with_pet(hungry: 50, autofeed: true) |> with_food(2)
      hungry = 50 - ctx.definition.fullness + ctx.definition.hunger_increase

      ticked = HungerHandler.tick(armed(session))

      assert %{hungry: ^hungry, intimate: 300} = ticked.pet
      assert Inventory.held_amount(ticked.game_state.inventory, @apple_juice) == 1
      assert %Pet{hungry: ^hungry, intimate: 300} = Repo.get!(Pet, ticked.pet.pet_id)
      assert_receive {:send, _, {:pet_food_result, %PetFoodResult{success: true}}}
    end
  end

  describe "feed/1" do
    test "overfeeding costs intimacy and fills hunger up to 100", ctx do
      session = ctx |> spawned() |> with_pet(hungry: 95) |> with_food(1)
      expected = 250 + ctx.definition.intimacy_overfed

      fed = HungerHandler.feed(session)

      assert %{hungry: 100, intimate: ^expected} = fed.pet
      assert Inventory.held_amount(fed.game_state.inventory, @apple_juice) == 0
      assert %Pet{hungry: 100, intimate: ^expected} = Repo.get!(Pet, fed.pet.pet_id)
      assert_state_change(:PET_STATE_HUNGER, 100)
      assert_state_change(:PET_STATE_INTIMACY, expected)

      assert_receive {:send, _,
                      {:pet_food_result,
                       %PetFoodResult{success: true, food_item_id: @apple_juice}}}
    end

    test "without the food only the failure is sent", ctx do
      session = spawned(ctx)

      assert HungerHandler.feed(session) == session

      assert_receive {:send, _,
                      {:pet_food_result,
                       %PetFoodResult{success: false, food_item_id: @apple_juice}}}

      refute_received {:send, _, {:pet_state_change, _}}
    end
  end

  describe "owner_died/1" do
    test "costs the species' owner-death intimacy", ctx do
      session = spawned(ctx)
      expected = 250 + ctx.definition.intimacy_owner_die

      updated = HungerHandler.owner_died(session)

      assert expected in 1..249
      assert updated.pet.intimate == expected
      assert Repo.get!(Pet, updated.pet.pet_id).intimate == expected
      assert_state_change(:PET_STATE_INTIMACY, expected)
    end

    test "costs intimacy and deletes the egg when it reaches zero", ctx do
      session = ctx |> spawned() |> with_pet(intimate: 1)
      updated = HungerHandler.owner_died(session)
      assert updated.pet.intimate == 0
      assert Egg.find(updated.game_state.inventory, updated.pet.pet_id) == :error
      assert_state_change(:PET_STATE_INTIMACY, 0)
    end

    test "a pet that already ran away still sends its intimacy", ctx do
      session = ctx |> spawned() |> with_pet(intimate: 0)
      assert HungerHandler.owner_died(session).pet.intimate == 0
      assert_state_change(:PET_STATE_INTIMACY, 0)
    end

    test "does not cost intimacy on a noexppenalty map", ctx do
      session = spawned(ctx)
      :ok = MapFlags.set_runtime(@map, :noexppenalty, true)
      assert HungerHandler.owner_died(session).pet.intimate == 250
      refute_received {:send, _, {:pet_state_change, _}}
    end
  end

  describe "set_intimate/2" do
    test "intimacy 0 deletes the egg", ctx do
      session = spawned(ctx)
      {:ok, egg} = Egg.find(session.game_state.inventory, session.pet.pet_id)

      updated = HungerHandler.set_intimate(session, -5)

      assert updated.pet.intimate == 0
      assert Egg.find(updated.game_state.inventory, updated.pet.pet_id) == :error
      refute Repo.get(InventoryItem, egg.id)
      assert Repo.get!(Pet, updated.pet.pet_id).intimate == 0
      assert_receive {:send, _, {:item_removed, _}}
    end

    test "a new grade rewrites card3 and keeps the rename bit", ctx do
      session = ctx |> spawned() |> with_renamed_egg()

      updated = HungerHandler.set_intimate(session, 800)

      assert updated.pet.intimate == 800
      {:ok, egg} = Egg.find(updated.game_state.inventory, updated.pet.pet_id)
      assert egg.card3 == Egg.card3(1, 800)
      assert Repo.get!(InventoryItem, egg.id).card3 == Egg.card3(1, 800)
    end
  end

  describe "set_autofeed/2" do
    test "is ignored for a pet that does not allow autofeed", ctx do
      session = spawned(ctx)

      assert HungerHandler.set_autofeed(session, true) == :error
      refute Repo.get!(Pet, session.pet.pet_id).autofeed
    end

    @tag game_mode: :renewal
    test "turns autofeed on for a pet that allows it", ctx do
      definition = Enum.find(Catalog.all(), & &1.allow_auto_feed)
      session = spawned(%{ctx | definition: definition})

      assert {:ok, updated} = HungerHandler.set_autofeed(session, true)
      assert updated.pet.autofeed
      assert Repo.get!(Pet, session.pet.pet_id).autofeed
    end
  end

  defp spawned(ctx) do
    {:ok, inventory, pet} =
      Persistence.create_with_egg(
        ctx.account.id,
        ctx.character.id,
        ctx.definition,
        %{level: 1, name: "Pet"},
        %{},
        :infinity
      )

    {:ok, inventory, _pet} =
      Persistence.hatch(pet, ctx.account.id, ctx.character.id, inventory)

    character = Repo.get!(Character, ctx.character.id)
    session = LifecycleHandler.restore(session(character, inventory), character)
    session = LifecycleHandler.spawned_after_map_load(session)
    flush_sent()
    session
  end

  defp with_pet(%SessionState{pet: pet} = session, fields) do
    pet = struct!(pet, fields)
    Repo.update_all(from(p in Pet, where: p.id == ^pet.pet_id), set: row_fields(fields))
    %{session | pet: pet}
  end

  defp row_fields(fields), do: Keyword.take(fields, [:hungry, :intimate, :autofeed])

  defp with_food(%SessionState{game_state: owner} = session, amount) do
    {:ok, item} = ItemManagement.get_item_by_id(@apple_juice)
    {:ok, inventory, change} = Inventory.add(owner.inventory, item, amount)

    {:ok, inventory} =
      InventoryOps.persist_change(owner.character_id, owner.inventory, inventory, change)

    %{session | game_state: %{owner | inventory: inventory}}
  end

  defp with_renamed_egg(%SessionState{game_state: owner} = session) do
    {index, egg} =
      Enum.find(owner.inventory, fn {_index, item} -> Egg.pet_id(item) == session.pet.pet_id end)

    egg = %{egg | card3: Egg.card3(1, 250)}
    Repo.update_all(from(i in InventoryItem, where: i.id == ^egg.id), set: [card3: egg.card3])
    %{session | game_state: %{owner | inventory: %{owner.inventory | index => egg}}}
  end

  defp armed(%SessionState{} = session) do
    ref = make_ref()
    %{session | pet_runtime: %{session.pet_runtime | hunger_timer_ref: ref}}
  end

  defp assert_timer(%SessionState{pet_runtime: %{hunger_timer_ref: ref}}, interval) do
    assert is_reference(ref)
    remaining = Process.read_timer(ref)
    assert remaining > interval - 1_000 and remaining <= interval
  end

  defp assert_state_change(type, value) do
    assert_receive {:send, _, {:pet_state_change, %PetStateChange{type: ^type, value: ^value}}}
  end

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
