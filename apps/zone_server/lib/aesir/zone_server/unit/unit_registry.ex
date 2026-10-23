defmodule Aesir.ZoneServer.Unit.UnitRegistry do
  @moduledoc """
  Central registry for all active units in the zone.
  Provides polymorphic access to any unit type (players, mobs, NPCs, pets, etc.).

  Units are stored in an ETS table with the key format: {unit_type, unit_id}
  This allows efficient lookup and management of all unit types in the zone.
  """

  require Logger

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cell
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @type unit_type :: Unit.unit_type()
  @type unit_id :: integer()
  @type unit_key :: {unit_type(), unit_id()}
  @type unit_data :: {module(), any(), pid() | nil}

  @counted_types [:player, :mob, :homunculus, :npc]

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
    previous_target = registered_attack_target(key)
    initialize_target_count(key)
    :ets.insert(table_for(:unit_registry), {key, module, state, pid})
    :ets.insert(table_for(:unit_registry_id_index), {unit_id, unit_type})
    retarget(previous_target, attack_target(unit_type, state))
    :ok
  end

  @doc """
  Unregisters a unit from the registry.
  """
  @spec unregister_unit(unit_type(), unit_id()) :: :ok
  def unregister_unit(unit_type, unit_id) do
    key = {unit_type, unit_id}
    adjust_target_count(registered_attack_target(key), -1)
    :ets.delete(table_for(:unit_registry), key)
    :ets.delete(table_for(:unit_registry), {:target_count, unit_type, unit_id})
    :ets.delete_object(table_for(:unit_registry_id_index), {unit_id, unit_type})

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
      [{^key, module, old_state, pid}] ->
        previous_target = attack_target(unit_type, old_state)
        :ets.insert(table_for(:unit_registry), {key, module, new_state, pid})
        retarget(previous_target, attack_target(unit_type, new_state))
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Reads the unit's standing-attack counter in constant time.

  The eight-bit counter saturates at 255. Excess increments are lost, and a
  departing attacker decrements the stored count, never a reconstructed scan.
  Metadata stays with a claimed unit ID while its map presence is detached.
  """
  @spec target_count(unit_key()) :: 0..255
  def target_count({type, id}) do
    case :ets.lookup(table_for(:unit_registry), {:target_count, type, id}) do
      [{_key, count}] -> count
      [] -> 0
    end
  end

  @doc "Checks a published unit's standing attack and in-flight skill targets."
  @spec targeting?(unit_type(), map(), unit_key()) :: boolean()
  def targeting?(type, state, target) do
    attack_target(type, state) == target or skill_target(type, state) == target
  end

  defp skill_target(:mob, %{casting: %{unit_target: {:unit, type, id}}}), do: {type, id}

  defp skill_target(type, %{casting: %{target: {:unit, {target_type, id}}}})
       when type in [:player, :homunculus],
       do: {target_type, id}

  defp skill_target(:player, %{casting: %{target: {:unit, id}}}) when is_integer(id) do
    case unit_type_for(id) do
      {:ok, type} -> {type, id}
      {:error, :not_found} -> nil
    end
  end

  defp skill_target(_type, _state), do: nil

  defp initialize_target_count({type, id}) when type in @counted_types,
    do: :ets.insert_new(table_for(:unit_registry), {{:target_count, type, id}, 0})

  defp initialize_target_count(_key), do: :ok

  defp registered_attack_target({type, _id} = key) do
    case :ets.lookup(table_for(:unit_registry), key) do
      [{^key, _module, state, _pid}] -> attack_target(type, state)
      [] -> nil
    end
  end

  defp attack_target(:player, %{
         combat_target_id: id,
         action_state: action,
         continuous_attack_timer: timer
       })
       when is_integer(id) and action in [:attacking, :casting, :idle] and is_reference(timer) do
    case unit_type_for(id) do
      {:ok, type} -> {type, id}
      {:error, :not_found} -> nil
    end
  end

  defp attack_target(:mob, %{attack_target: {type, id}}), do: {type, id}
  defp attack_target(:homunculus, %{target: {type, id}, action_state: :attacking}), do: {type, id}
  defp attack_target(_type, _state), do: nil

  defp retarget(target, target), do: :ok

  defp retarget(previous, current) do
    adjust_target_count(previous, -1)
    adjust_target_count(current, 1)
  end

  defp adjust_target_count({type, id}, delta) when type in @counted_types do
    limit = if delta > 0, do: 255, else: 0

    try do
      :ets.update_counter(
        table_for(:unit_registry),
        {:target_count, type, id},
        {2, delta, limit, limit}
      )

      :ok
    rescue
      # The target may have been removed after the attacker's state was read.
      ArgumentError -> :ok
    end
  end

  defp adjust_target_count(_target, _delta), do: :ok

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

  @doc "Checks whether any registered unit owns `unit_id` through the ID index."
  @spec unit_id_exists?(unit_id()) :: boolean()
  def unit_id_exists?(unit_id) do
    :ets.member(table_for(:unit_registry_id_index), unit_id)
  end

  @doc """
  Resolves which unit type owns `unit_id` through the ID index.

  Numeric unit IDs are unique across types (`claim_unit_id/2` reserves the key),
  so this recovers the type for a caller that only carries a bare id.
  """
  @spec unit_type_for(unit_id()) :: {:ok, unit_type()} | {:error, :not_found}
  def unit_type_for(unit_id) do
    case :ets.lookup(table_for(:unit_registry_id_index), unit_id) do
      [{^unit_id, unit_type} | _rest] -> {:ok, unit_type}
      [] -> {:error, :not_found}
    end
  end

  @doc "Atomically reserves a numeric unit ID for a unit type."
  @spec claim_unit_id(unit_id(), unit_type()) :: boolean()
  def claim_unit_id(unit_id, unit_type) do
    :ets.insert_new(table_for(:unit_registry_id_index), {unit_id, unit_type})
  end

  @doc "Deletes a typed registry row while retaining its numeric ID claim."
  @spec detach_unit(unit_type(), unit_id()) :: :ok
  def detach_unit(unit_type, unit_id) do
    adjust_target_count(registered_attack_target({unit_type, unit_id}), -1)
    :ets.delete(table_for(:unit_registry), {unit_type, unit_id})
    :ok
  end

  @doc "Releases an unregistered numeric unit ID claim."
  @spec release_unit_id(unit_id(), unit_type()) :: :ok
  def release_unit_id(unit_id, unit_type) do
    :ets.delete_object(table_for(:unit_registry_id_index), {unit_id, unit_type})
    :ok
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
  Counts a player's living summons of one kind on one map, and how many of
  them are the given mob class.

  Returns `{kind_count, class_count}`. Only summons whose `summon_kind` is
  `summon_kind` are counted, so another plant or another sphere class neither
  fills nor fails the class cap.
  """
  @spec count_owned_summons(integer(), String.t(), atom(), integer()) ::
          {non_neg_integer(), non_neg_integer()}
  def count_owned_summons(owner_player_id, map_name, summon_kind, mob_id) do
    :mob
    |> list_units_by_type()
    |> Enum.reduce({0, 0}, fn instance_id, counts ->
      case get_unit(:mob, instance_id) do
        {:ok, {_module, %MobState{} = mob, _pid}} ->
          count_owned_summon(mob, counts, owner_player_id, map_name, summon_kind, mob_id)

        {:ok, _other} ->
          counts

        {:error, _missing} ->
          counts
      end
    end)
  end

  defp count_owned_summon(
         %MobState{
           owner_player_id: owner_player_id,
           map_name: map_name,
           summon_kind: summon_kind,
           mob_id: mob_id,
           is_dead: false
         },
         {kind_count, class_count},
         owner_player_id,
         map_name,
         summon_kind,
         mob_id
       ),
       do: {kind_count + 1, class_count + 1}

  defp count_owned_summon(
         %MobState{
           owner_player_id: owner_player_id,
           map_name: map_name,
           summon_kind: summon_kind,
           is_dead: false
         },
         {kind_count, class_count},
         owner_player_id,
         map_name,
         summon_kind,
         _mob_id
       ),
       do: {kind_count + 1, class_count}

  defp count_owned_summon(_mob, counts, _owner, _map, _kind, _mob_id), do: counts

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

    Enum.each(keys_to_delete, fn {unit_type, unit_id} = key ->
      unregister_unit(unit_type, unit_id)
      Logger.debug("Cleaned up unit #{inspect(key)} due to process death")
    end)

    :ok
  end

  @doc "Registers a targetable skill-unit cell under its owning manager process."
  @spec register_skill_unit(Cell.t(), pid()) :: :ok
  def register_skill_unit(%Cell{} = cell, manager_pid) when is_pid(manager_pid) do
    register_unit(:skill_unit, cell.cell_id, CombatTarget, cell, manager_pid)
  end

  @doc "Removes a skill-unit cell from the generic unit registry."
  @spec unregister_skill_unit(non_neg_integer()) :: :ok
  def unregister_skill_unit(cell_id), do: unregister_unit(:skill_unit, cell_id)

  # Player-specific helper functions

  @doc """
  Registers a player unit in the registry.

  The full `PlayerState` is stored as the unit state under the `PlayerState`
  module, mirroring how mobs are registered with `MobState`. This keeps
  `get_unit_info/2` working (it dispatches `get_entity_info/1` on the stored
  module) and is the single source of truth for the player's live state.

  Also maintains a reverse `account_id -> char_id` lookup index.
  """
  @spec register_player(PlayerState.t(), pid()) :: :ok
  def register_player(%PlayerState{character_id: char_id, account_id: account_id} = state, pid) do
    register_unit(:player, char_id, PlayerState, state, pid)

    :ets.insert(table_for(:unit_registry), {{:account_index, account_id}, char_id})

    :ok
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
  Gets a player's character name from the registry.

  Returns {:ok, char_name} or {:error, :not_found}
  """
  @spec get_player_name(unit_id()) :: {:ok, String.t()} | {:error, :not_found}
  def get_player_name(char_id) do
    case get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{character_name: char_name}, _pid}} ->
        {:ok, char_name}

      {:ok, _} ->
        {:error, :not_found}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  @doc """
  Unregisters a player from the registry.

  When `owner_pid` is given, the entry is only removed if it is still owned by
  that pid. This prevents a terminating session from deleting the registry entry
  of a newer session that has since taken over the same `char_id`.
  """
  @spec unregister_player(unit_id(), pid() | nil) :: :ok
  def unregister_player(char_id, owner_pid \\ nil) do
    case get_unit(:player, char_id) do
      {:ok, {_module, state, stored_pid}} when owner_pid == nil or owner_pid == stored_pid ->
        cleanup_account_index(state)
        unregister_unit(:player, char_id)

      {:ok, {_module, _state, stored_pid}} ->
        Logger.debug(
          "Skipping unregister of char #{char_id}: registry owned by #{inspect(stored_pid)}, not #{inspect(owner_pid)}"
        )

        :ok

      {:error, :not_found} ->
        :ok
    end
  end

  defp cleanup_account_index(%{account_id: account_id}) do
    :ets.delete(table_for(:unit_registry), {:account_index, account_id})
    :ok
  end

  defp cleanup_account_index(_state), do: :ok

  @doc """
  Gets a character ID from account ID using the reverse lookup index.

  Returns {:ok, char_id} or {:error, :not_found}
  """
  @spec get_char_id_by_account(integer()) :: {:ok, unit_id()} | {:error, :not_found}
  def get_char_id_by_account(account_id) do
    case :ets.lookup(table_for(:unit_registry), {:account_index, account_id}) do
      [{{:account_index, ^account_id}, char_id}] -> {:ok, char_id}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Lists all player units currently in the registry.
  """
  @spec list_players() :: [unit_id()]
  def list_players do
    list_units_by_type(:player)
  end

  @doc """
  Finds an online player's character id by exact name match.

  No name index exists (only the `account_id` reverse index), so this scans
  `list_players/0`; the online player count is small enough for a linear scan
  to be cheap.
  """
  @spec find_char_id_by_name(String.t()) :: {:ok, unit_id()} | {:error, :not_found}
  def find_char_id_by_name(name) do
    :player
    |> list_units_by_type()
    |> Enum.find_value({:error, :not_found}, fn char_id ->
      case get_player_name(char_id) do
        {:ok, ^name} -> {:ok, char_id}
        _ -> nil
      end
    end)
  end
end
