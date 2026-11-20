defmodule Aesir.ZoneServer.Mmo.PetManagement.EggGrantCallersTest do
  # The ETS setup also resets the shared warp index.
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.Models.Pet
  alias Aesir.Factory, as: DbFactory
  alias Aesir.Net.PickupItemRequest
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Roller
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @poring_egg 9001
  @egg_drop %{
    mob_id: 1002,
    drops: [%MobDrop{item: "Poring_Egg", rate: 10_000}],
    mob_level: 1,
    fixed_item_drop?: true,
    map: "prontera",
    x: 150,
    y: 150,
    ownership: nil,
    boss?: false
  }

  setup :set_mimic_from_context
  setup :setup_ets_tables

  setup do
    character = DbFactory.insert(:character)
    %{state: %SessionState{game_state: PlayerState.new(character), connection_pid: self()}}
  end

  test "getitem grants a hatchable egg; getgroupitem and MVP prizes grant plain ones", %{
    state: state
  } do
    {{:ok, _}, state} = ScriptEffectHandler.apply_op({:give_item, @poring_egg, 1}, state)

    entry = build(:item_group_entry, item_id: @poring_egg, identify?: true)
    subgroup = build(:item_subgroup, algorithm: :all, entries: [entry])
    grants = :item_group |> build(subgroups: [subgroup]) |> Roller.roll_full()

    {{:ok, _}, state} = ScriptEffectHandler.apply_op({:give_group_items, grants}, state)

    {{:ok, gs}, _state} =
      ScriptEffectHandler.apply_op({:give_plain_item, @poring_egg, %{}}, state)

    assert [pet_id, nil, nil] = gs.inventory |> Enum.sort() |> Enum.map(&Egg.pet_id(elem(&1, 1)))
    assert Repo.get(Pet, pet_id)
  end

  test "an overweight egg grant gives neither a pet nor a plain egg", %{state: state} do
    state = put_in(state.game_state.stats.modifiers.passive[:max_weight_bonus], -100_000)

    {{:ok, gs}, _state} = ScriptEffectHandler.apply_op({:give_item, @poring_egg, 1}, state)

    assert gs.inventory == %{}
    assert Repo.aggregate(Pet, :count) == 0
    assert_received {:send, _ch, {:item_add_failed, _}}
  end

  test "getrandgroupitem creates one pet per egg unit", %{state: state} do
    entry =
      build(:item_group_entry, item_id: @poring_egg, amount: 2, identify?: true, stacked?: false)

    subgroup = build(:item_subgroup, algorithm: :all, entries: [entry])
    grants = :item_group |> build(subgroups: [subgroup]) |> Roller.roll_full()

    {{:ok, gs}, _state} = ScriptEffectHandler.apply_op({:give_rand_group_items, grants}, state)

    ids = gs.inventory |> Map.values() |> Enum.map(&Egg.pet_id/1)
    assert length(Enum.uniq(ids)) == 2 and Enum.all?(ids)
  end

  test "@item creates a pet per egg unit", %{state: state} do
    {:ok, egg} = Items.by_id(@poring_egg)
    {:noreply, state} = InventoryManager.handle_give_item_cast(egg, 2, state)

    ids = state.game_state.inventory |> Map.values() |> Enum.map(&Egg.pet_id/1)
    assert length(Enum.uniq(ids)) == 2 and Enum.all?(ids)
  end

  test "picking up a floor egg keeps it as it is and creates no pet", %{state: state} do
    state = update_in(state.game_state, &%{&1 | map_name: "prontera", x: 150, y: 150})

    floor_egg =
      build(:ground_item,
        nameid: @poring_egg,
        x: 151,
        y: 150,
        attribute: 1,
        cards: [256, 5, 0, 0]
      )

    :ok = GroundItemStore.put("prontera", floor_egg)

    stub(Coordinator, :claim_item, fn map, id, _char, _party -> GroundItemStore.claim(map, id) end)

    {:noreply, state} =
      PacketHandler.handle_message(%PickupItemRequest{ground_id: floor_egg.id}, state)

    assert [%{card0: 256, card1: 5, card2: 0, card3: 0, attribute: 1}] =
             Map.values(state.game_state.inventory)

    assert Repo.aggregate(Pet, :count) == 0
    assert {:error, :gone} = GroundItemStore.get("prontera", floor_egg.id)
  end

  test "a rolled egg drop goes to the killer as a pet, never to the floor", %{state: state} do
    reject(&Coordinator.drop_items/4)
    reject(&Coordinator.drop_items/5)

    payload = Map.put(@egg_drop, :final_source, {:player, state.game_state.character_id})
    {:noreply, state} = LootHandler.mob_killed(payload, state, fn _ -> 10_000 end)

    assert [pet_id] = state.game_state.inventory |> Map.values() |> Enum.map(&Egg.pet_id/1)
    assert Repo.get(Pet, pet_id)
  end

  test "a rolled egg drop is sent to another top loot owner's session", %{state: state} do
    test = self()
    owner = spawn_link(fn -> forward_call(test) end)
    owner_id = state.game_state.character_id + 1
    stub(UnitRegistry, :get_player_pid, fn ^owner_id -> {:ok, owner} end)
    reject(&Coordinator.drop_items/5)

    {:noreply, ^state} =
      LootHandler.mob_killed(
        %{@egg_drop | ownership: %LootOwnership{first: owner_id}},
        state,
        fn _ -> 10_000 end
      )

    assert_receive {:session_call, {:npc, {:script_apply, {:give_egg, @poring_egg}}}}
  end

  test "with no loot owner and a non-player killing blow the egg is floored", %{state: state} do
    test = self()

    stub(Coordinator, :drop_items, fn "prontera", items, _x, _y, _opts ->
      send(test, {:floored, Enum.map(items, &elem(&1, 0))})
      :ok
    end)

    payload =
      Map.merge(@egg_drop, %{ownership: %LootOwnership{}, final_source: {:homunculus, 55}})

    {:noreply, state} = LootHandler.mob_killed(payload, state, fn _ -> 10_000 end)

    assert_received {:floored, [@poring_egg]}
    assert state.game_state.inventory == %{}
    assert Repo.aggregate(Pet, :count) == 0
  end

  defp forward_call(test) do
    receive do
      {:"$gen_call", from, msg} ->
        send(test, {:session_call, msg})
        GenServer.reply(from, {:ok, %{}})
    end
  end
end
