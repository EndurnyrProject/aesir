defmodule Aesir.ZoneServer.Integration.ItemDropTest do
  @moduledoc """
  End-to-end coverage of the item-drop loop on the live stack: the killer's
  `PlayerSession` rolls a mob's drop table, the map `Coordinator` places the
  result in `GroundItemStore` and broadcasts it, a nearby player sees it, and a
  manual `PickupItemRequest` gives the item and clears the ground.

  Every step drives the real session/handler/coordinator/store subsystems. Mob
  death is delivered through the exact PubSub seam the live `MobSession` uses
  (`announce_kill/2` broadcasts `{:mob_killed, payload}` to the killer's player
  topic), with a real `MobDrop` table containing a rate-10000 entry so the roll is
  deterministic (a guaranteed drop, no `:rand` seeding needed; with
  `mob_level == base_level` the renewal level penalty is the 100% no-op band).
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.Net.ItemAdded
  alias Aesir.Net.ItemOnGround
  alias Aesir.Net.ItemVanished
  alias Aesir.Net.PickupItemRequest
  alias Aesir.Net.PickupResult
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Phoenix.PubSub

  @map "prontera"
  # Red Potion (item db id 501, weight 70) — a plain stackable to drop.
  @potion 501
  @ttl_ms 60_000

  setup do
    {:ok, coordinator} = ensure_coordinator(@map)
    %{coordinator: coordinator}
  end

  describe "drop -> see -> pick up" do
    test "killing a mob drops an item the player sees and can pick up" do
      player = start_looter(name: "Looter", position: {150, 150})

      # Kill a mob right under the player's feet with a guaranteed Red Potion
      # drop. The level matches the killer's so the level penalty is a no-op.
      kill_mob_near(player, x: 150, y: 150, drops: [%MobDrop{item: "Red_Potion", rate: 10_000}])

      ground_id =
        assert_item_on_ground(nameid: @potion, x: 150, y: 150, is_falling: true)

      assert [%GroundItem{id: ^ground_id}] = GroundItemStore.query_in_range(@map, 150, 150, 0)
      flush_packets()

      # Manual pickup from on top of the item.
      simulate_incoming_message(player.pid, %PickupItemRequest{ground_id: ground_id})

      assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 1_000
      assert_receive {:packet_sent, %PickupResult{ground_id: ^ground_id, result: :OK}, _}, 1_000

      assert_receive {:packet_sent, %ItemVanished{ground_id: ^ground_id, reason: :PICKED_UP}, _},
                     1_000

      # The item is in the inventory and gone from the ground.
      assert held(get_player_state(player.pid).inventory, @potion) == 1
      assert GroundItemStore.query_in_range(@map, 150, 150, 0) == []

      assert {:ok, [%InventoryItem{nameid: @potion, amount: 1}]} =
               load_inventory(player.character.id)
    end
  end

  describe "pickup distance" do
    test "a player more than 2 cells away gets TOO_FAR and the item stays" do
      player = start_looter(name: "FarOff", position: {150, 150})

      item = GroundItem.new(@potion, 1, 160, 160)
      GroundItemStore.put(@map, item)
      on_exit(fn -> GroundItemStore.claim(@map, item.id) end)
      flush_packets()

      simulate_incoming_message(player.pid, %PickupItemRequest{ground_id: item.id})

      assert_receive {:packet_sent, %PickupResult{ground_id: id, result: :TOO_FAR}, _}, 1_000
      assert id == item.id

      assert [%GroundItem{id: kept}] = GroundItemStore.query_in_range(@map, 160, 160, 0)
      assert kept == item.id
    end
  end

  describe "expiry" do
    test "an item past its lifetime is swept and a nearby player sees it vanish" do
      player = start_looter(name: "Watcher", position: {150, 150})

      stale = %GroundItem{
        id: System.unique_integer([:positive, :monotonic]),
        nameid: @potion,
        amount: 1,
        x: 150,
        y: 150,
        identified: true,
        dropped_at: System.monotonic_time(:millisecond) - (@ttl_ms + 1_000)
      }

      GroundItemStore.put(@map, stale)
      flush_packets()

      # Drive the coordinator's real expiry sweep deterministically instead of
      # waiting out the 60 s lifetime.
      send(player.coordinator, :expire_ground_items)

      assert_receive {:packet_sent, %ItemVanished{ground_id: id, reason: :EXPIRED}, _}, 1_000
      assert id == stale.id
      assert GroundItemStore.query_in_range(@map, 150, 150, 0) == []
    end
  end

  describe "walk-up discovery" do
    test "spawning into range of a lying item sends a non-falling ItemOnGround" do
      item = GroundItem.new(@potion, 1, 150, 150)
      GroundItemStore.put(@map, item)
      on_exit(fn -> GroundItemStore.claim(@map, item.id) end)

      # The item is already on the ground; the player walks up (spawns into
      # range), so the visibility diff sends it as a non-falling item. Keep the
      # spawn packets (no flush) so the discovery packet survives.
      player = start_looter(name: "Stroller", position: {150, 150}, flush: false)

      assert_receive {:packet_sent,
                      %ItemOnGround{ground_id: id, nameid: @potion, is_falling: false}, _},
                     1_000

      assert id == item.id
      assert MapSet.member?(get_player_state(player.pid).visible_items, item.id)
    end
  end

  # Drives the real mob-death reward seam: the live MobSession broadcasts this
  # exact payload to "player:#{attacker_id}"; the killer session rolls and places.
  defp kill_mob_near(player, opts) do
    base_level = player.character.base_level

    payload = %{
      mob_id: 1002,
      base_exp: 50,
      job_exp: 25,
      drops: Keyword.fetch!(opts, :drops),
      mob_level: base_level,
      map: @map,
      x: Keyword.fetch!(opts, :x),
      y: Keyword.fetch!(opts, :y)
    }

    PubSub.broadcast(Aesir.PubSub, "player:#{player.character.id}", {:mob_killed, payload})
  end

  defp assert_item_on_ground(opts) do
    nameid = Keyword.fetch!(opts, :nameid)
    x = Keyword.fetch!(opts, :x)
    y = Keyword.fetch!(opts, :y)
    falling = Keyword.fetch!(opts, :is_falling)

    assert_receive {:packet_sent,
                    %ItemOnGround{
                      ground_id: ground_id,
                      nameid: ^nameid,
                      x: ^x,
                      y: ^y,
                      is_falling: ^falling
                    }, _},
                   1_000

    ground_id
  end

  defp start_looter(opts) do
    character = insert_character(Keyword.fetch!(opts, :name))

    session =
      start_player_session(
        character: character,
        map_name: @map,
        position: Keyword.fetch!(opts, :position)
      )

    on_exit(fn -> end_player_session(session) end)
    if Keyword.get(opts, :flush, true), do: flush_packets()

    session
    |> Map.put(:character, character)
    |> Map.put(:coordinator, coordinator_pid())
  end

  defp insert_character(prefix) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "#{prefix}#{uniq}",
        userid: "#{prefix}#{uniq}",
        user_pass: "password",
        email: "#{prefix}#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "#{prefix}#{uniq}",
        class: 0,
        base_level: 50,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp held(inventory, nameid) do
    Enum.reduce(inventory, 0, fn
      {_index, %InventoryItem{nameid: ^nameid, amount: amount}}, acc -> acc + amount
      _entry, acc -> acc
    end)
  end

  defp load_inventory(char_id) do
    Aesir.ZoneServer.Unit.Inventory.Persistence.load_inventory(char_id)
  end

  defp ensure_coordinator(map_name) do
    {:ok, _pid} = ensure_coordinator(map_name, 40)
  end

  defp ensure_coordinator(map_name, 0), do: MapManager.get_coordinator(map_name)

  defp ensure_coordinator(map_name, retries) do
    case MapManager.get_coordinator(map_name) do
      {:ok, pid} ->
        {:ok, pid}

      _ ->
        Process.sleep(50)
        ensure_coordinator(map_name, retries - 1)
    end
  end

  defp coordinator_pid do
    {:ok, pid} = MapManager.get_coordinator(@map)
    pid
  end
end
