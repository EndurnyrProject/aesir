defmodule Aesir.ZoneServer.Map.Coordinator do
  use GenServer

  require Logger

  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Phoenix.PubSub

  defstruct [
    :map_name,
    :map_data,
    :npcs,
    :monsters,
    :items,
    :weather,
    :pvp_enabled,
    :pk_enabled
  ]

  @doc """
  Starts a map coordinator.
  """
  def start_link(opts) do
    map_name = Keyword.fetch!(opts, :map_name)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(map_name))
  end

  @doc """
  Spawns an item on the ground.
  """
  def spawn_item(map_name, item_id, amount, x, y) do
    GenServer.cast(via_tuple(map_name), {:spawn_item, item_id, amount, x, y})
  end

  @doc """
  Changes map weather.
  """
  def set_weather(map_name, weather_type) do
    GenServer.cast(via_tuple(map_name), {:set_weather, weather_type})
  end

  @doc """
  Broadcasts an announcement to all players on the map.
  """
  def announce(map_name, message) do
    GenServer.cast(via_tuple(map_name), {:announce, message})
  end

  @doc """
  Gets map information.
  """
  def get_map_info(map_name) do
    GenServer.call(via_tuple(map_name), :get_info)
  end

  @impl true
  def init(opts) do
    map_name = Keyword.fetch!(opts, :map_name)

    state = %__MODULE__{
      map_name: map_name,
      map_data: load_map_data(map_name),
      npcs: %{},
      monsters: %{},
      items: %{},
      weather: :clear,
      pvp_enabled: Keyword.get(opts, :pvp_enabled, false),
      pk_enabled: Keyword.get(opts, :pk_enabled, false)
    }

    schedule_cleanup()

    Logger.info("MapCoordinator started for #{map_name}")

    {:ok, state}
  end

  @impl true
  def handle_cast({:spawn_item, item_id, amount, x, y}, state) do
    instance_id = generate_item_id()

    item = %{
      id: instance_id,
      item_id: item_id,
      amount: amount,
      x: x,
      y: y,
      spawned_at: System.system_time(:second)
    }

    new_items = Map.put(state.items, instance_id, item)

    broadcast_item_spawn(state.map_name, item, x, y)

    {:noreply, %{state | items: new_items}}
  end

  @impl true
  def handle_cast({:set_weather, weather_type}, state) do
    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{state.map_name}",
      {:weather_changed, weather_type}
    )

    {:noreply, %{state | weather: weather_type}}
  end

  @impl true
  def handle_cast({:announce, message}, state) do
    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{state.map_name}",
      {:map_announcement, message}
    )

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_info, _from, state) do
    info = %{
      map_name: state.map_name,
      weather: state.weather,
      pvp_enabled: state.pvp_enabled,
      pk_enabled: state.pk_enabled,
      item_count: map_size(state.items),
      monster_count: map_size(state.monsters),
      npc_count: map_size(state.npcs),
      player_count: SpatialIndex.count_players_on_map(state.map_name)
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info(:cleanup_items, state) do
    # Remove items older than 3 minutes
    now = System.system_time(:second)
    # 3 minutes
    timeout = 180

    new_items =
      state.items
      |> Enum.reject(fn {_id, item} ->
        now - item.spawned_at > timeout
      end)
      |> Map.new()

    expired = Map.keys(state.items) -- Map.keys(new_items)

    Enum.each(expired, fn item_id ->
      item = state.items[item_id]
      broadcast_item_remove(state.map_name, item_id, item.x, item.y)
    end)

    schedule_cleanup()

    {:noreply, %{state | items: new_items}}
  end

  defp via_tuple(map_name) do
    {:via, Registry, {Aesir.ZoneServer.MapRegistry, map_name}}
  end

  defp load_map_data(map_name) do
    # TODO: Load actual map data
    Logger.debug("Loading map data for #{map_name}")
    nil
  end

  defp schedule_cleanup, do: Process.send_after(self(), :cleanup_items, 60_000)

  defp generate_item_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16()

  defp broadcast_item_spawn(map_name, item, x, y) do
    cell_x = div(x, 8)
    cell_y = div(y, 8)

    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{map_name}:cell:#{cell_x}:#{cell_y}",
      {:item_spawned, item}
    )
  end

  defp broadcast_item_remove(map_name, item_id, x, y) do
    cell_x = div(x, 8)
    cell_y = div(y, 8)

    PubSub.broadcast(
      Aesir.PubSub,
      "map:#{map_name}:cell:#{cell_x}:#{cell_y}",
      {:item_removed, item_id}
    )
  end
end
