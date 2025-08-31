defmodule Aesir.ZoneServer.Unit.UnitRegistry do
  @moduledoc """
  Central registry for all active units in the zone.
  Provides polymorphic access to any unit type (players, mobs, NPCs, pets, etc.).

  Units are stored in an ETS table with the key format: {unit_type, unit_id}
  This allows efficient lookup and management of all unit types in the zone.
  """

  require Logger

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Unit.Entity

  @type unit_type :: Entity.unit_type()
  @type unit_id :: integer()
  @type unit_key :: {unit_type(), unit_id()}
  @type unit_data :: {module(), any(), pid() | nil}

  @doc """
  Registers a unit in the registry.

  ## Parameters
    - unit_type: Type of unit (:player, :mob, :npc, etc.)
    - unit_id: Unique identifier for the unit
    - module: The module that implements the Entity behaviour
    - state: The current state of the unit
    - pid: Optional process PID for units with GenServer processes
  """
  @spec register_unit(unit_type(), unit_id(), module(), any(), pid() | nil) :: :ok
  def register_unit(unit_type, unit_id, module, state, pid \\ nil) do
    key = {unit_type, unit_id}
    :ets.insert(table_for(:unit_registry), {key, module, state, pid})

    Logger.debug("Registered #{unit_type} unit with ID #{unit_id}")

    :ok
  end

  @doc """
  Unregisters a unit from the registry.
  """
  @spec unregister_unit(unit_type(), unit_id()) :: :ok
  def unregister_unit(unit_type, unit_id) do
    key = {unit_type, unit_id}
    :ets.delete(table_for(:unit_registry), key)

    Logger.debug("Unregistered #{unit_type} unit with ID #{unit_id}")

    :ok
  end

  @doc """
  Gets a unit's data from the registry.

  Returns {:ok, {module, state, pid}} or {:error, :not_found}
  """
  @spec get_unit(unit_type(), unit_id()) :: {:ok, unit_data()} | {:error, :not_found}
  def get_unit(unit_type, unit_id) do
    case :ets.lookup(table_for(:unit_registry), {unit_type, unit_id}) do
      [{_key, module, state, pid}] -> {:ok, {module, state, pid}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets a unit's entity information using the Entity behaviour.

  This is a convenience function that calls get_entity_info on the unit's module.
  """
  @spec get_unit_info(unit_type(), unit_id()) :: {:ok, map()} | {:error, :not_found}
  def get_unit_info(unit_type, unit_id) do
    case get_unit(unit_type, unit_id) do
      {:ok, {module, state, _pid}} ->
        {:ok, module.get_entity_info(state)}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Updates a unit's state in the registry.
  """
  @spec update_unit_state(unit_type(), unit_id(), any()) :: :ok | {:error, :not_found}
  def update_unit_state(unit_type, unit_id, new_state) do
    key = {unit_type, unit_id}

    case :ets.lookup(table_for(:unit_registry), key) do
      [{^key, module, _old_state, pid}] ->
        :ets.insert(table_for(:unit_registry), {key, module, new_state, pid})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Checks if a unit exists in the registry.
  """
  @spec unit_exists?(unit_type(), unit_id()) :: boolean()
  def unit_exists?(unit_type, unit_id) do
    case get_unit(unit_type, unit_id) do
      {:ok, _} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Lists all units of a specific type.
  """
  @spec list_units_by_type(unit_type()) :: [unit_id()]
  def list_units_by_type(unit_type) do
    table_for(:unit_registry)
    |> :ets.match({{unit_type, :"$1"}, :_, :_, :_})
    |> Enum.map(&List.first/1)
  end

  @doc """
  Gets the total count of units by type.
  """
  @spec count_units_by_type(unit_type()) :: non_neg_integer()
  def count_units_by_type(unit_type) do
    unit_type
    |> list_units_by_type()
    |> length()
  end

  @doc """
  Gets the total count of all units in the registry.
  """
  @spec count_all_units() :: non_neg_integer()
  def count_all_units do
    :ets.info(table_for(:unit_registry), :size)
  end

  @doc """
  Cleans up units associated with a dead process.
  This should be called when a process monitoring units dies.
  """
  @spec cleanup_units_for_pid(pid()) :: :ok
  def cleanup_units_for_pid(pid) do
    match_spec = [
      {
        {:"$1", :"$2", :"$3", pid},
        [],
        [:"$1"]
      }
    ]

    keys_to_delete = :ets.select(table_for(:unit_registry), match_spec)

    Enum.each(keys_to_delete, fn key ->
      :ets.delete(table_for(:unit_registry), key)
      Logger.debug("Cleaned up unit #{inspect(key)} due to process death")
    end)

    :ok
  end

  # Player-specific helper functions

  @doc """
  Registers a player unit in the registry.

  This is a convenience function specifically for player units that stores
  the account_id in the state for compatibility with existing code.
  """
  @spec register_player(unit_id(), integer(), pid()) :: :ok
  def register_player(char_id, account_id, pid) do
    # Store account_id in state for compatibility
    state = %{account_id: account_id}
    register_unit(:player, char_id, __MODULE__, state, pid)
  end

  @doc """
  Gets a player's PID from the registry.

  Returns {:ok, pid} or {:error, :not_found}
  """
  @spec get_player_pid(unit_id()) :: {:ok, pid()} | {:error, :not_found}
  def get_player_pid(char_id) do
    case get_unit(:player, char_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> {:ok, pid}
      {:ok, {_module, _state, nil}} -> {:error, :not_found}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  @doc """
  Gets a player's PID and account_id from the registry.

  Returns {:ok, {pid, account_id}} or {:error, :not_found}
  """
  @spec get_player_with_account(unit_id()) :: {:ok, {pid(), integer()}} | {:error, :not_found}
  def get_player_with_account(char_id) do
    case get_unit(:player, char_id) do
      {:ok, {_module, %{account_id: account_id}, pid}} when is_pid(pid) ->
        {:ok, {pid, account_id}}

      {:ok, _} ->
        {:error, :not_found}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Unregisters a player from the registry.

  This is a convenience function for player units.
  """
  @spec unregister_player(unit_id()) :: :ok
  def unregister_player(char_id) do
    unregister_unit(:player, char_id)
  end

  @doc """
  Lists all player units currently in the registry.
  """
  @spec list_players() :: [unit_id()]
  def list_players do
    list_units_by_type(:player)
  end
end
