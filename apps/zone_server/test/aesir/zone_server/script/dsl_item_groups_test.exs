defmodule Aesir.ZoneServer.Script.DslItemGroupsTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Announcement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.ItemGroupPool
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryOps
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.Modifiers
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression
  alias Aesir.ZoneServer.Unit.Stats.BaseStats

  setup :set_mimic_private
  setup :verify_on_exit!

  defmodule StubSession do
    use GenServer

    def start_link(reply_fun), do: GenServer.start_link(__MODULE__, reply_fun)

    @impl true
    def init(reply_fun), do: {:ok, reply_fun}

    @impl true
    def handle_call({:npc, {:script_apply, op}}, _from, reply_fun) do
      send(:dsl_item_groups_probe, {:script_apply, op})
      {:reply, reply_fun.(op), reply_fun}
    end
  end

  setup do
    Aesir.TestProbe.register!(:dsl_item_groups_probe)
    previous_catalog = :persistent_term.get(ItemGroups, :missing)

    on_exit(fn ->
      case previous_catalog do
        :missing -> :persistent_term.erase(ItemGroups)
        catalog -> :persistent_term.put(ItemGroups, catalog)
      end
    end)

    :ok
  end

  test "get_group_item grants all and random entries in item-use context" do
    install_group(:item_box, [
      %SubGroup{number: 0, algorithm: :all, entries: [%Entry{item_id: 501, rate: 1}]},
      %SubGroup{number: 1, algorithm: :random, entries: [%Entry{item_id: 502, rate: 1}]}
    ])

    stub(InventoryOps, :add, fn 1, inventory, _stats, definition, 1, _opts ->
      index = map_size(inventory)
      added = %InventoryItem{nameid: definition.id, amount: 1}
      {:ok, Map.put(inventory, index, added), {:added, index, added}}
    end)

    result = Dsl.get_group_item(item_ctx(), :item_box)

    assert result.status == :ok
    assert result.game_state.inventory[0].nameid == 501
    assert result.game_state.inventory[1].nameid == 502
  end

  test "get_rand_group_item grants the requested quantity of one picked entry" do
    install_group(:rand_box, [
      %SubGroup{number: 3, algorithm: :random, entries: [%Entry{item_id: 501, rate: 1}]}
    ])

    stub(InventoryOps, :add, fn 1, inventory, _stats, definition, amount, _opts ->
      index = map_size(inventory)
      added = %InventoryItem{nameid: definition.id, amount: amount}
      {:ok, Map.put(inventory, index, added), {:added, index, added}}
    end)

    result = Dsl.get_rand_group_item(item_ctx(), :rand_box, 2, 3)

    assert result.status == :ok
    assert %{0 => %InventoryItem{nameid: 501, amount: 2}} = result.game_state.inventory
  end

  test "get_rand_group_item sends one grant and halts on a refusal" do
    install_group(:rand_one, [
      %SubGroup{
        number: 1,
        algorithm: :random,
        entries: [%Entry{item_id: 501, rate: 1}, %Entry{item_id: 502, rate: 1}]
      }
    ])

    {:ok, session} =
      StubSession.start_link(fn {:give_rand_group_items, _grants} ->
        {:error, :overweight}
      end)

    result = Dsl.get_rand_group_item(npc_ctx(session), :rand_one, 2, 1)

    assert result.status == {:error, :overweight}
    assert_received {:script_apply, {:give_rand_group_items, [grant]}}
    assert grant.item_id in [501, 502]
    assert grant.amount == 2
  end

  test "get_rand_group_item refuses before any call when the inventory has no blank slot" do
    install_group(:rand_full, [
      %SubGroup{number: 1, algorithm: :random, entries: [%Entry{item_id: 501, rate: 1}]}
    ])

    {:ok, session} = StubSession.start_link(fn _op -> {:ok, item_ctx().game_state} end)

    full =
      Map.new(0..99, fn index -> {index, %InventoryItem{nameid: 90_000 + index, amount: 1}} end)

    ctx = %{npc_ctx(session) | game_state: %{item_ctx().game_state | inventory: full}}

    assert Dsl.get_rand_group_item(ctx, :rand_full, 1, 1).status == {:error, :inventory_full}
    refute_received {:script_apply, _op}
  end

  test "get_group_item routes NPC grants through the session seam" do
    install_group(:npc_box, [
      %SubGroup{number: 0, algorithm: :all, entries: [%Entry{item_id: 501, rate: 1}]},
      %SubGroup{number: 1, algorithm: :random, entries: [%Entry{item_id: 502, rate: 1}]}
    ])

    {:ok, session} =
      StubSession.start_link(fn {:give_group_items, grants} ->
        inventory =
          grants
          |> Enum.with_index()
          |> Map.new(fn {grant, index} ->
            {index, %InventoryItem{nameid: grant.item_id, amount: grant.amount}}
          end)

        {:ok, %{item_ctx().game_state | inventory: inventory}}
      end)

    result = Dsl.get_group_item(npc_ctx(session), :npc_box)

    assert Enum.map(result.game_state.inventory, fn {_index, item} -> item.nameid end) == [
             501,
             502
           ]

    assert_received {:script_apply, {:give_group_items, grants}}
    assert Enum.map(grants, & &1.item_id) == [501, 502]
  end

  test "an overflowing grant keeps its shared-pool draw" do
    stub(InventoryOps, :add, fn _char_id, inventory, _stats, item_def, amount, opts ->
      case Inventory.add(inventory, item_def, amount, opts, :infinity) do
        {:ok, new_inventory, change} -> {:ok, new_inventory, change}
        {:error, reason} -> {:error, reason}
      end
    end)

    install_pool_group(:item_full, 1101, 2, 101)
    owner = ItemGroupPool.ensure_pool(:item_full)
    before_counts = pool_counts(owner)

    result = Dsl.get_group_item(item_ctx(), :item_full)

    assert result.status == :ok
    assert pool_counts(owner) != before_counts
  end

  test "an NPC session error halts without rolling the shared-pool draw back" do
    install_pool_group(:npc_full, 501, 2, 1)
    owner = ItemGroupPool.ensure_pool(:npc_full)
    before_counts = pool_counts(owner)
    original = item_ctx().game_state
    {:ok, session} = StubSession.start_link(fn _op -> {:error, :insufficient_space} end)

    result = Dsl.get_group_item(%{npc_ctx(session) | game_state: original}, :npc_full)

    assert result.status == {:error, :insufficient_space}
    assert result.game_state.inventory == %{}
    assert pool_counts(owner) != before_counts
  end

  test "a detached ctx announces successful grants" do
    test_pid = self()

    expect(Announcement, :to_all, fn opts ->
      send(test_pid, {:announced, opts})
      :ok
    end)

    stub(InventoryOps, :add, fn 1, inventory, _stats, definition, amount, _opts ->
      index = map_size(inventory)
      added = %InventoryItem{nameid: definition.id, amount: amount}
      {:ok, Map.put(inventory, index, added), {:added, index, added}}
    end)

    result = Dsl.commit_grants(item_ctx(), [grant(501, announced?: true)])

    assert result.status == :ok
    assert_receive {:announced, %{text: "Obtained item 501.", style: :TOP}}
  end

  test "group_rand_item returns a valid id without depleting a shared pool" do
    install_pool_group(:read_pool, 501, 2, 1)
    owner = ItemGroupPool.ensure_pool(:read_pool)
    before_counts = pool_counts(owner)

    assert Dsl.group_rand_item(item_ctx(), :read_pool, 0) == 501
    assert pool_counts(owner) == before_counts
  end

  test "unknown groups halt effects and raise for a read op" do
    assert Dsl.get_group_item(item_ctx(), :missing).status == {:error, :unknown_item_group}

    assert Dsl.get_rand_group_item(item_ctx(), :missing, 1, 0).status ==
             {:error, :unknown_item_group}

    assert_raise ArgumentError, ~r/cannot resolve item group/, fn ->
      Dsl.group_rand_item(item_ctx(), :missing, 0)
    end
  end

  defp install_group(key, subgroups) do
    :persistent_term.put(ItemGroups, %{key => %Group{key: key, subgroups: subgroups}})
  end

  defp install_pool_group(key, item_id, rate, amount) do
    subgroup = %SubGroup{
      number: 0,
      algorithm: :shared_pool,
      entries: [%Entry{item_id: item_id, rate: rate, amount: amount}]
    }

    install_group(key, [subgroup])
  end

  defp pool_counts(owner), do: owner |> :sys.get_state() |> get_in([:subs, 0])

  defp grant(item_id, opts) do
    %{
      item_id: item_id,
      amount: 1,
      identify?: false,
      refine: 0,
      grade: 0,
      bound: nil,
      unique_id?: false,
      duration_min: 0,
      named?: false,
      announced?: Keyword.get(opts, :announced?, false),
      drawn: nil
    }
  end

  defp npc_ctx(session), do: %{item_ctx() | session_pid: session, source: {:npc, :test}}

  defp item_ctx do
    %Ctx{
      char_id: 1,
      account_id: 100,
      connection_pid: self(),
      session_pid: nil,
      game_state: %PlayerState{
        character_id: 1,
        character_name: "Tester",
        account_id: 100,
        inventory: %{},
        stats: stats()
      },
      source: {:item, 1}
    }
  end

  defp stats do
    %Stats{
      base_stats: %BaseStats{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      progression: %PlayerProgression{job_id: 0},
      modifiers: %Modifiers{equipment: %{}, status_effects: %{}, job_bonuses: %{}}
    }
  end
end
