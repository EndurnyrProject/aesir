defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroupsIntegrationTest do
  use Aesir.DataCase, async: false

  import Aesir.TestEtsSetup

  @moduletag :integration

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.NpcDialog
  alias Aesir.Net.NpcInteract
  alias Aesir.Repo
  alias Aesir.ZoneServer.Content.Npc.Re.Cities.Dewata.LazyYoungMan
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ScriptCompiler
  alias Aesir.ZoneServer.Npc.Transpiler.Codegen
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Interaction
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.Handlers.ItemHandler
  alias Aesir.ZoneServer.Unit.Player.Handlers.ScriptEffectHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState

  @box_id 12_609
  @box_group :old_ore_box
  @palm_juice_id 11_534
  @npc_gid 0x5000_1234

  defmodule Session do
    use GenServer

    def start_link(state), do: GenServer.start_link(__MODULE__, state)

    @impl true
    def init(state), do: {:ok, state}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, state) do
      {reply, new_state} = ScriptEffectHandler.apply_op(op, state)
      {:reply, reply, new_state}
    end

    def handle_call(:game_state, _from, state), do: {:reply, state.game_state, state}
  end

  setup_all do
    :ok = ItemGroups.reload()
    :ok = ScriptCompiler.compile_all!()

    source = "getitem groupranditem(IG_GiftBox, 6), 1; end;"

    {:ok, generated} =
      Codegen.generate(source, %{
        module: "Aesir.ZoneServer.Mmo.ItemManagement.ItemGroupsIntegrationTest.GroupRandNpc",
        kind: :script,
        source: "item_groups_fixture.txt:1",
        spawns: [
          %{map: "prontera", x: 10, y: 10, dir: 0, sprite: 58, name: "Group Rand NPC"}
        ],
        functions: %{}
      })

    [{module, _}] = Code.compile_string(generated)
    %{group_rand_npc: module}
  end

  setup :setup_ets_tables

  setup do
    character = create_character()
    {:ok, character: character}
  end

  test "a real box grants all entries and one weighted pool entry before being consumed", %{
    character: character
  } do
    box = insert_item(character.id, @box_id)
    state = session_state(character, %{0 => box})
    {:ok, group} = ItemGroups.fetch(@box_group)

    assert {:noreply, committed} = ItemHandler.handle_use_item(2, state)

    amounts = inventory_amounts(committed.game_state.inventory)
    all = Enum.find(group.subgroups, &(&1.algorithm == :all))
    pool = Enum.find(group.subgroups, &(&1.algorithm == :shared_pool))

    assert amounts[984] == 2
    assert amounts[985] == 2

    selected = Enum.filter(pool.entries, &Map.has_key?(amounts, &1.item_id))
    assert [%{item_id: selected_id, amount: selected_amount}] = selected
    assert amounts[selected_id] == selected_amount
    refute Map.has_key?(amounts, @box_id)
    assert Enum.all?(all.entries, &(amounts[&1.item_id] == &1.amount))
  end

  test "the transpiled Lazy Young Man grants GiftBox contents through an NPC interaction", %{
    character: character
  } do
    palm_juice = insert_item(character.id, @palm_juice_id)
    state = session_state(character, %{0 => palm_juice})
    state = put_in(state.game_state.vars["MaxWeight"], 100_000)
    {:ok, session} = Session.start_link(state)
    {:ok, interaction} = Interaction.start(session, LazyYoungMan, npc_ctx(state.game_state))

    assert_receive {:send, _channel, {:npc_dialog, %NpcDialog{expect: :NEXT}}}, 500
    continue(interaction)
    assert_receive {:send, _channel, {:npc_dialog, %NpcDialog{expect: :MENU}}}, 500
    choose(interaction, 1)
    assert_receive {:send, _channel, {:npc_dialog, %NpcDialog{expect: :CLOSE}}}, 500

    game_state = GenServer.call(session, :game_state)
    {:ok, giftbox} = ItemGroups.fetch(:giftbox)
    valid_ids = giftbox |> hd_subgroup_entries() |> MapSet.new(& &1.item_id)

    refute Map.has_key?(inventory_amounts(game_state.inventory), @palm_juice_id)
    assert [granted] = Map.values(game_state.inventory)
    assert MapSet.member?(valid_ids, granted.nameid)
  end

  test "a full inventory keeps the box and restores the shared pool", %{character: character} do
    box = insert_item(character.id, @box_id)

    inventory =
      Map.put(
        Map.new(1..99, &{&1, %InventoryItem{nameid: 900_000 + &1, amount: 1}}),
        0,
        box
      )

    owner = ItemGroupPool.ensure_pool(@box_group)
    before_counts = pool_counts(owner)
    state = session_state(character, inventory)

    assert {:noreply, rejected} = ItemHandler.handle_use_item(2, state)

    assert rejected.game_state.inventory == inventory
    assert pool_counts(owner) == before_counts
    assert [%InventoryItem{nameid: @box_id, amount: 1}] = Persistence.load_inventory(character.id)
  end

  test "getitem groupranditem grants an item selected by the transpiled read", %{
    character: character,
    group_rand_npc: module
  } do
    state = session_state(character, %{})
    {:ok, session} = Session.start_link(state)
    {:ok, interaction} = Interaction.start(session, module, npc_ctx(state.game_state))
    monitor = Process.monitor(interaction)

    assert_receive {:DOWN, ^monitor, :process, ^interaction, :normal}, 500

    game_state = GenServer.call(session, :game_state)
    {:ok, giftbox} = ItemGroups.fetch(:giftbox)
    valid_ids = giftbox |> hd_subgroup_entries() |> MapSet.new(& &1.item_id)

    assert [granted] = Map.values(game_state.inventory)
    assert MapSet.member?(valid_ids, granted.nameid)
  end

  defp create_character do
    suffix = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "igroup#{suffix}",
        userid: "ig#{suffix}",
        user_pass: "password",
        email: "ig#{suffix}@test.local"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "ItemGroup#{suffix}",
      class: 0,
      base_level: 99,
      str: 99,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 10,
      last_map: "prontera",
      last_x: 10,
      last_y: 10,
      save_map: "prontera",
      save_x: 10,
      save_y: 10
    })
    |> Repo.insert!()
  end

  defp insert_item(char_id, item_id) do
    {:ok, item} = Persistence.insert_item(char_id, %{nameid: item_id, amount: 1, identify: 1})
    item
  end

  defp session_state(character, inventory) do
    game_state = %{PlayerState.new(character) | inventory: inventory}
    %SessionState{connection_pid: self(), game_state: game_state}
  end

  defp npc_ctx(game_state) do
    %Ctx{
      char_id: game_state.character_id,
      account_id: game_state.account_id,
      connection_pid: self(),
      game_state: game_state,
      source: {:npc, LazyYoungMan.npc_id()},
      npc_gid: @npc_gid
    }
  end

  defp continue(pid) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @npc_gid, response: {:continue, true}}})
  end

  defp choose(pid, choice) do
    send(pid, {:npc_interact, %NpcInteract{npc_id: @npc_gid, response: {:choice, choice}}})
  end

  defp inventory_amounts(inventory) do
    Map.new(inventory, fn {_index, item} -> {item.nameid, item.amount} end)
  end

  defp hd_subgroup_entries(group), do: hd(group.subgroups).entries
  defp pool_counts(owner), do: owner |> :sys.get_state() |> get_in([:subs, 2])
end
