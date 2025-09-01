defmodule Aesir.ZoneServer.Mmo.MobManagement.MobDataLoader do
  @moduledoc """
  GenServer responsible for loading and managing mob data from configuration files.
  Provides efficient access to mob information through ETS tables.
  """
  use GenServer

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDrop
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn

  require Logger

  @doc """
  Starts the MobDataLoader GenServer.
  """
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets a mob definition by ID or aegis name.
  """
  @spec get_mob(integer() | atom()) :: {:ok, MobDefinition.t()} | {:error, :mob_not_found}
  def get_mob(mob_id) when is_integer(mob_id) do
    lookup_mob_by_id(mob_id)
  end

  def get_mob(aegis_name) when is_atom(aegis_name) do
    lookup_mob_by_name(aegis_name)
  end

  @doc """
  Gets all mob definitions.
  """
  @spec get_all_mobs() :: [MobDefinition.t()]
  def get_all_mobs do
    fetch_all_mobs()
  end

  @doc """
  Gets spawn data for a specific map.
  """
  @spec get_spawns_for_map(String.t()) :: {:ok, [MobSpawn.t()]} | {:error, :no_spawns}
  def get_spawns_for_map(map_name) when is_binary(map_name) do
    lookup_spawns_by_map(map_name)
  end

  @doc """
  Gets all spawn data.
  """
  @spec get_all_spawns() :: %{String.t() => [MobSpawn.t()]}
  def get_all_spawns do
    fetch_all_spawns()
  end

  @doc """
  Reloads mob data from configuration files.
  For development use only.
  """
  @spec reload() :: :ok
  def reload do
    GenServer.cast(__MODULE__, :reload)
  end

  @impl true
  def init(_opts) do
    case load_all_data() do
      :ok ->
        {:ok, %{loaded: true}}

      {:error, reason} ->
        Logger.error("Failed to load mob data: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_cast(:reload, state) do
    :ets.delete_all_objects(table_for(:mob_data))
    :ets.delete_all_objects(table_for(:mob_data_by_name))
    :ets.delete_all_objects(table_for(:mob_spawn_data))

    case load_all_data() do
      :ok ->
        Logger.info("Mob data reloaded successfully")
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to reload mob data: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  defp load_all_data do
    with :ok <- load_mob_definitions() do
      load_spawn_data()
    end
  end

  defp load_mob_definitions do
    mob_data_path = Application.app_dir(:zone_server, "priv/db/re/mob_db.exs")

    try do
      {raw_data, _} = Code.eval_file(mob_data_path)

      case transform_mob_data(raw_data) do
        {:ok, mobs} ->
          store_mobs(mobs)
          Logger.info("Loaded #{length(mobs)} mob definitions successfully")
          :ok

        {:error, reasons} ->
          formatted_errors = Enum.join(reasons, "\n  - ")
          {:error, "Failed to load mob data. Errors:\n  - #{formatted_errors}"}
      end
    rescue
      e ->
        {:error, "Failed to load mob data file: #{Exception.message(e)}"}
    end
  end

  defp load_spawn_data do
    spawn_data_path = Application.app_dir(:zone_server, "priv/db/re/mob_spawn.exs")

    try do
      {raw_data, _} = Code.eval_file(spawn_data_path)

      case transform_spawn_data(raw_data) do
        {:ok, spawn_map} ->
          store_spawns(spawn_map)

          spawn_count =
            spawn_map
            |> Map.values()
            |> Enum.map(&length/1)
            |> Enum.sum()

          Logger.info("Loaded #{spawn_count} spawn entries for #{map_size(spawn_map)} maps")
          :ok

        {:error, reasons} ->
          formatted_errors = Enum.join(reasons, "\n  - ")
          {:error, "Failed to load spawn data. Errors:\n  - #{formatted_errors}"}
      end
    rescue
      e ->
        {:error, "Failed to load spawn data file: #{Exception.message(e)}"}
    end
  end

  defp transform_mob_data(raw_data) when is_list(raw_data) do
    {mobs, errors} =
      Enum.reduce(raw_data, {[], []}, fn mob_map, {mobs, errors} ->
        case build_mob_definition(mob_map) do
          {:ok, mob} -> {[mob | mobs], errors}
          {:error, reason} -> {mobs, [reason | errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.reverse(mobs)}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp transform_spawn_data(raw_data) when is_map(raw_data) do
    {spawn_map, errors} =
      Enum.reduce(raw_data, {%{}, []}, fn {map_name, spawns}, {acc_map, errors} ->
        case build_spawn_list(spawns, map_name) do
          {:ok, spawn_list} ->
            {Map.put(acc_map, map_name, spawn_list), errors}

          {:error, reason} ->
            {acc_map, ["Map #{map_name}: #{reason}" | errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, spawn_map}
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp build_mob_definition(mob_map) when is_map(mob_map) do
    drops =
      mob_map
      |> Map.get(:drops, [])
      |> Enum.map(&MobDrop.from_map/1)

    mob = %MobDefinition{
      id: Map.fetch!(mob_map, :id),
      aegis_name: Map.fetch!(mob_map, :aegis_name),
      name: Map.fetch!(mob_map, :name),
      level: Map.fetch!(mob_map, :level),
      hp: Map.fetch!(mob_map, :hp),
      sp: Map.get(mob_map, :sp, 0),
      base_exp: Map.get(mob_map, :base_exp, 0),
      job_exp: Map.get(mob_map, :job_exp, 0),
      atk_min: Map.fetch!(mob_map, :atk_min),
      atk_max: Map.fetch!(mob_map, :atk_max),
      def: Map.get(mob_map, :def, 0),
      mdef: Map.get(mob_map, :mdef, 0),
      stats: Map.fetch!(mob_map, :stats),
      attack_range: Map.fetch!(mob_map, :attack_range),
      skill_range: Map.get(mob_map, :skill_range, 10),
      chase_range: Map.get(mob_map, :chase_range, 12),
      size: Map.fetch!(mob_map, :size),
      race: Map.fetch!(mob_map, :race),
      element: Map.fetch!(mob_map, :element),
      walk_speed: Map.fetch!(mob_map, :walk_speed),
      attack_delay: Map.fetch!(mob_map, :attack_delay),
      attack_motion: Map.fetch!(mob_map, :attack_motion),
      client_attack_motion: Map.fetch!(mob_map, :client_attack_motion),
      damage_motion: Map.fetch!(mob_map, :damage_motion),
      ai_type: Map.get(mob_map, :ai_type, 0),
      modes: Map.get(mob_map, :modes, []),
      drops: drops
    }

    {:ok, mob}
  rescue
    e ->
      mob_id = Map.get(mob_map, :id, "unknown")
      {:error, "Failed to build mob #{mob_id}: #{Exception.message(e)}"}
  end

  defp build_spawn_list(spawns, map_name) when is_list(spawns) do
    {spawn_list, errors} =
      Enum.reduce(spawns, {[], []}, fn spawn_map, {list, errors} ->
        try do
          spawn = MobSpawn.from_map(spawn_map)
          {[spawn | list], errors}
        rescue
          e ->
            {list, [Exception.message(e) | errors]}
        end
      end)

    if Enum.empty?(errors) do
      {:ok, Enum.reverse(spawn_list)}
    else
      {:error, "Failed spawns for #{map_name}: #{Enum.join(errors, ", ")}"}
    end
  end

  defp store_mobs(mobs) do
    Enum.each(mobs, fn mob = %MobDefinition{id: id, aegis_name: name} ->
      :ets.insert(table_for(:mob_data), {id, mob})
      :ets.insert(table_for(:mob_data_by_name), {name, mob})
    end)
  end

  defp store_spawns(spawn_map) do
    Enum.each(spawn_map, fn {map_name, spawn_list} ->
      :ets.insert(table_for(:mob_spawn_data), {map_name, spawn_list})
    end)
  end

  defp lookup_mob_by_id(mob_id) do
    case :ets.lookup(table_for(:mob_data), mob_id) do
      [{^mob_id, mob}] -> {:ok, mob}
      [] -> {:error, :mob_not_found}
    end
  end

  defp lookup_mob_by_name(aegis_name) do
    case :ets.lookup(table_for(:mob_data_by_name), aegis_name) do
      [{^aegis_name, mob}] -> {:ok, mob}
      [] -> {:error, :mob_not_found}
    end
  end

  defp lookup_spawns_by_map(map_name) do
    case :ets.lookup(table_for(:mob_spawn_data), map_name) do
      [{^map_name, spawns}] -> {:ok, spawns}
      [] -> {:error, :no_spawns}
    end
  end

  defp fetch_all_mobs do
    :ets.tab2list(table_for(:mob_data))
    |> Enum.map(fn {_id, mob} -> mob end)
  end

  defp fetch_all_spawns do
    :ets.tab2list(table_for(:mob_spawn_data))
    |> Map.new()
  end
end
