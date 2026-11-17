defmodule Aesir.ZoneServer.Mmo.PetManagement.EggGrantCallersTest do
  use Aesir.DataCase, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Pet
  alias Aesir.Net.PickupItemRequest
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.ItemDrop.LootOwnership
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.PetManagement.Egg
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryManager
  alias Aesir.ZoneServer.Unit.Player.Handlers.LootHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.PacketHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @poring_egg 9001

  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    Mimic.copy(Coordinator)
    Mimic.copy(UnitRegistry)
    %{state: session(insert_character())}
  end

  test "getitem grants a hatchable egg; getgroupitem and MVP prizes grant plain ones", %{
    state: state
  } do
    {{:ok, _}, state} = ScriptEffectHandler.apply_op({:give_item, @poring_egg, 1}, state)

    {{:ok, _}, state} =
      ScriptEffectHandler.apply_op({:give_group_items, [grant(@poring_egg)]}, state)

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
    {{:ok, gs}, _state} =
      ScriptEffectHandler.apply_op(
        {:give_rand_group_items, [grant(@poring_egg, amount: 2, stacked?: false)]},
        state
      )

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

    floor_egg = %GroundItem{
      id: 31,
      nameid: @poring_egg,
      amount: 1,
      x: 151,
      y: 150,
      sub_x: 3,
      sub_y: 3,
      identified: true,
      dropped_at: 0,
      attribute: 1,
      cards: [256, 5, 0, 0]
    }

    :ok = GroundItemStore.put("prontera", floor_egg)

    stub(Coordinator, :claim_item, fn map, id, _char, _party -> GroundItemStore.claim(map, id) end)

    {:noreply, state} =
      PacketHandler.handle_message(%PickupItemRequest{ground_id: 31}, state)

    assert [%{card0: 256, card1: 5, card2: 0, card3: 0, attribute: 1}] =
             Map.values(state.game_state.inventory)

    assert Repo.aggregate(Pet, :count) == 0
    assert {:error, :gone} = GroundItemStore.get("prontera", 31)
  end

  test "a rolled egg drop goes to the killer as a pet, never to the floor", %{state: state} do
    reject(&Coordinator.drop_items/4)
    reject(&Coordinator.drop_items/5)

    payload = Map.put(drop_payload(nil), :final_source, {:player, state.game_state.character_id})
    {:noreply, state} = LootHandler.mob_killed(payload, state, fn _ -> 10_000 end)

    assert [pet_id] = state.game_state.inventory |> Map.values() |> Enum.map(&Egg.pet_id/1)
    assert Repo.get(Pet, pet_id)
  end

  test "a rolled egg drop is sent to another top loot owner's session", %{state: state} do
    test = self()
    owner = spawn_link(fn -> forward_call(test) end)
    stub(UnitRegistry, :get_player_pid, fn 777 -> {:ok, owner} end)
    reject(&Coordinator.drop_items/5)

    {:noreply, ^state} =
      LootHandler.mob_killed(
        drop_payload(%LootOwnership{first: 777}),
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
      Map.put(drop_payload(%LootOwnership{}), :final_source, {:homunculus, 55})

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

  defp drop_payload(ownership) do
    %{
      mob_id: 1002,
      drops: [%MobDrop{item: "Poring_Egg", rate: 10_000}],
      mob_level: 1,
      fixed_item_drop?: true,
      map: "prontera",
      x: 150,
      y: 150,
      ownership: ownership,
      boss?: false
    }
  end

  defp grant(item_id, overrides \\ []) do
    Map.merge(
      %{
        item_id: item_id,
        amount: 1,
        identify?: true,
        refine: 0,
        grade: 0,
        bound: nil,
        unique_id?: false,
        duration_min: 0,
        named?: false,
        announced?: false,
        stacked?: true,
        refine_min: 0,
        refine_max: 0,
        grade_min: 0,
        grade_max: 0,
        drawn: nil
      },
      Map.new(overrides)
    )
  end

  defp session(character),
    do: %{game_state: PlayerState.new(character), connection_pid: self()}

  defp insert_character do
    suffix = System.unique_integer([:positive])

    account =
      Repo.insert!(
        Account.changeset(%Account{}, %{
          username: "egc#{suffix}",
          userid: "egc#{suffix}",
          user_pass: "password",
          email: "egc#{suffix}@example.com"
        })
      )

    Repo.insert!(
      Character.changeset(%Character{}, %{
        account_id: account.id,
        char_num: 0,
        name: "Egc#{suffix}",
        class: 1,
        base_level: 99,
        str: 50,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1
      })
    )
  end
end
