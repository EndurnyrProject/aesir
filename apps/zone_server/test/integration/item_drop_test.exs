defmodule Aesir.ZoneServer.Integration.ItemDropTest do
  @moduledoc """
  End-to-end coverage of the item-drop loop on the live stack: the killer's
  `PlayerSession` rolls a mob's drop table, the map `Coordinator` places the
  result in `GroundItemStore` and broadcasts it, a nearby player sees it, and a
  manual `PickupItemRequest` gives the item and clears the ground.

  Every step drives the real session/handler/coordinator/store subsystems. Mob
  death is delivered through the exact PubSub seam the live `MobSession` uses
  (`announce_kill/2` broadcasts `{:mob_killed, payload}` to the killer's player
  topic; EXP itself flows separately through `Unit.Mob.KillExp` and is not
  exercised here), with a real `MobDrop` table containing a rate-10000 entry
  so the roll is deterministic (a guaranteed drop, no `:rand` seeding needed).
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
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapManager
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItem
  alias Aesir.ZoneServer.Mmo.ItemDrop.GroundItemStore
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Pathfinding
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

      assert [%InventoryItem{nameid: @potion, amount: 1}] =
               load_inventory(player.character.id)
    end
  end

  describe "move-to-pickup" do
    test "a player more than 2 cells from a reachable item walks to it and picks it up" do
      origin = nearest_walkable({150, 150})
      player = start_looter(name: "Walker", position: origin)

      {item_x, item_y} = reachable_target(origin, 3)
      item = GroundItem.new(@potion, 1, item_x, item_y)
      GroundItemStore.put(@map, item)
      on_exit(fn -> GroundItemStore.claim(@map, item.id) end)
      flush_packets()

      # The item is out of pickup range, so the request walks the player to it
      # (move-to-pickup) and the pickup fires when movement completes.
      simulate_incoming_message(player.pid, %PickupItemRequest{ground_id: item.id})

      assert_receive {:packet_sent, %ItemAdded{nameid: @potion}, _}, 5_000
      assert_receive {:packet_sent, %PickupResult{ground_id: id, result: :OK}, _}, 5_000
      assert id == item.id

      assert_receive {:packet_sent, %ItemVanished{ground_id: ^id, reason: :PICKED_UP}, _}, 5_000

      assert held(get_player_state(player.pid).inventory, @potion) == 1
      assert GroundItemStore.query_in_range(@map, item_x, item_y, 0) == []
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
        sub_x: 3,
        sub_y: 3,
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
      drops: Keyword.fetch!(opts, :drops),
      mob_level: base_level,
      map: @map,
      x: Keyword.fetch!(opts, :x),
      y: Keyword.fetch!(opts, :y)
    }

    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{player.character.id}",
      {:loot, {:mob_killed, payload}}
    )
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
                      sub_x: sub_x,
                      sub_y: sub_y,
                      is_falling: ^falling
                    }, _},
                   1_000

    # The drop carries a real sub-cell offset so stacked items don't render on
    # top of each other (instead of the wire always shipping 0).
    assert sub_x in [3, 6, 9, 12]
    assert sub_y in [3, 6, 9, 12]

    ground_id
  end

  # Nearest walkable cell to a candidate spawn, so the move-to-pickup walk has a
  # real path origin regardless of the exact map geometry under the test point.
  defp nearest_walkable({ox, oy}) do
    for(d <- 0..10, dx <- -d..d, dy <- -d..d, do: {ox + dx, oy + dy})
    |> Enum.find(fn {x, y} -> MapCache.walkable?(@map, x, y) end)
    |> case do
      nil -> flunk("no walkable cell found near #{ox},#{oy}")
      cell -> cell
    end
  end

  # A walkable cell at least `min_dist` cells (Manhattan) from `origin` that the
  # pathfinder can actually reach — the move-to-pickup destination.
  defp reachable_target(origin, min_dist) do
    {:ok, map_data} = MapCache.get(@map)
    {ox, oy} = origin

    candidates =
      for d <- min_dist..(min_dist + 5),
          dx <- -d..d,
          dy <- -d..d,
          abs(dx) + abs(dy) >= min_dist,
          do: {ox + dx, oy + dy}

    candidates
    |> Enum.find_value(fn {x, y} ->
      with true <- MapCache.walkable?(@map, x, y),
           {:ok, [_ | _]} <- Pathfinding.find_path(map_data, origin, {x, y}) do
        {x, y}
      else
        _ -> nil
      end
    end)
    |> case do
      nil -> flunk("no reachable cell found near #{ox},#{oy}")
      cell -> cell
    end
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
