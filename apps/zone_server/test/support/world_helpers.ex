defmodule Aesir.ZoneServer.WorldHelpers do
  @moduledoc """
  Helper functions for querying and manipulating the game world state
  in integration tests.
  """

  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Gets the current HP of a unit.

  ## Examples

      hp = get_unit_hp(:mob, mob_id)
      assert hp < max_hp
  """
  def get_unit_hp(unit_type, unit_id) do
    case get_unit_field(unit_type, unit_id, :hp) do
      nil -> nil
      hp -> hp
    end
  end

  @doc """
  Gets the maximum HP of a unit.

  ## Examples

      max_hp = get_unit_max_hp(:player, player_id)
  """
  def get_unit_max_hp(unit_type, unit_id) do
    get_unit_field(unit_type, unit_id, :max_hp)
  end

  @doc """
  Gets the current position of a unit.

  ## Examples

      {x, y} = get_unit_position(:player, player_id)
      assert x == 150
  """
  def get_unit_position(unit_type, unit_id) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, _map}} -> {x, y}
      _ -> nil
    end
  end

  @doc """
  Gets the map a unit is currently on.

  ## Examples

      map = get_unit_map(:player, player_id)
      assert map == "prontera"
  """
  def get_unit_map(unit_type, unit_id) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {_x, _y, map}} -> map
      _ -> nil
    end
  end

  @doc """
  Gets a specific field from a unit's state.

  ## Examples

      level = get_unit_field(:mob, mob_id, :level)
  """
  def get_unit_field(unit_type, unit_id, field) do
    state = get_unit_full_state(unit_type, unit_id)
    if state, do: Map.get(state, field), else: nil
  end

  @doc """
  Gets the full state of a unit.

  ## Examples

      state = get_unit_full_state(:player, player_id)
      IO.inspect(state)
  """
  def get_unit_full_state(unit_type, unit_id) do
    case unit_type do
      :player ->
        case UnitRegistry.get_player_pid(unit_id) do
          {:ok, pid} -> PlayerSession.get_state(pid)
          _ -> nil
        end

      :mob ->
        case UnitRegistry.get_unit(:mob, unit_id) do
          {:ok, {_module, mob_state, _pid}} -> mob_state
          _ -> nil
        end

      _ ->
        nil
    end
  end

  @doc """
  Gets the current stats of a player.

  ## Examples

      stats = get_player_stats(player_pid)
      assert stats.str > 0
  """
  def get_player_stats(player_pid) when is_pid(player_pid) do
    PlayerSession.get_current_stats(player_pid)
  end

  @doc """
  Gets the current state of a player.

  ## Examples

      state = get_player_state(player_pid)
      assert state.stats != nil
  """
  def get_player_state(player_pid) when is_pid(player_pid) do
    session_state = PlayerSession.get_state(player_pid)
    # Extract the game_state which is the actual PlayerState
    session_state.game_state
  end

  @doc """
  Gets the current state of a mob.

  ## Examples

      state = get_mob_state(mob_pid)
      assert state.hp < state.max_hp
  """
  def get_mob_state(mob_pid) when is_pid(mob_pid) do
    case GenServer.call(mob_pid, :get_state) do
      state when is_map(state) -> state
      _ -> nil
    end
  end

  @doc """
  Counts the number of units of a specific type on a map.

  ## Examples

      mob_count = count_units_on_map(:mob, "prontera")
      assert mob_count == 5
  """
  def count_units_on_map(unit_type, map_name) do
    case unit_type do
      :player ->
        SpatialIndex.get_players_on_map(map_name) |> length()

      :mob ->
        SpatialIndex.get_units_on_map(:mob, map_name) |> length()

      _ ->
        0
    end
  end

  @doc """
  Checks if a specific unit exists in the world.

  ## Examples

      assert unit_exists?(:mob, mob_id)
  """
  def unit_exists?(unit_type, unit_id) do
    case unit_type do
      :player ->
        case UnitRegistry.get_player_pid(unit_id) do
          {:ok, _} -> true
          _ -> false
        end

      :mob ->
        case UnitRegistry.get_unit(:mob, unit_id) do
          {:ok, _} -> true
          _ -> false
        end

      _ ->
        false
    end
  end

  @doc """
  Gets all player IDs currently in the game.

  ## Examples

      player_ids = get_all_player_ids()
  """
  def get_all_player_ids do
    UnitRegistry.list_players()
    |> Enum.map(fn {player_id, _pid} -> player_id end)
  end

  @doc """
  Gets all mob IDs currently in the game.

  ## Examples

      mob_ids = get_all_mob_ids()
  """
  def get_all_mob_ids do
    UnitRegistry.list_units_by_type(:mob)
    |> Enum.map(fn {mob_id, _data} -> mob_id end)
  end

  @doc """
  Waits for a unit to reach a specific HP value.
  Useful for testing damage over time effects.

  ## Examples

      wait_for_hp(:mob, mob_id, 50, 1000)
  """
  def wait_for_hp(unit_type, unit_id, target_hp, timeout \\ 1000) do
    wait_for_condition(
      fn -> get_unit_hp(unit_type, unit_id) <= target_hp end,
      timeout
    )
  end

  @doc """
  Waits for a unit to die (HP reaches 0).

  ## Examples

      wait_for_death(:mob, mob_id)
  """
  def wait_for_death(unit_type, unit_id, timeout \\ 2000) do
    wait_for_condition(
      fn ->
        hp = get_unit_hp(unit_type, unit_id)
        hp == nil || hp <= 0
      end,
      timeout
    )
  end

  @doc """
  Waits for a unit to move to a specific position.

  ## Examples

      wait_for_position(:player, player_id, {160, 160})
  """
  def wait_for_position(unit_type, unit_id, {target_x, target_y}, timeout \\ 2000) do
    wait_for_condition(
      fn ->
        case get_unit_position(unit_type, unit_id) do
          {^target_x, ^target_y} -> true
          _ -> false
        end
      end,
      timeout
    )
  end

  @doc """
  Gets the aggro list of a mob.

  ## Examples

      aggro_list = get_mob_aggro_list(mob.unit_id)
      assert player_id in aggro_list
  """
  def get_mob_aggro_list(mob_id) do
    case get_unit_full_state(:mob, mob_id) do
      %{aggro_list: aggro_list} -> aggro_list
      _ -> []
    end
  end

  @doc """
  Checks if a mob has a specific player on its aggro list.

  ## Examples

      assert mob_has_aggro?(mob_id, player_id)
  """
  def mob_has_aggro?(mob_id, player_id) do
    aggro_list = get_mob_aggro_list(mob_id)
    Enum.any?(aggro_list, fn {char_id, _damage} -> char_id == player_id end)
  end

  # Private helper functions

  defp wait_for_condition(condition_fn, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_wait_for_condition(condition_fn, deadline)
  end

  defp do_wait_for_condition(condition_fn, deadline) do
    if condition_fn.() do
      :ok
    else
      now = System.monotonic_time(:millisecond)

      if now < deadline do
        Process.sleep(50)
        do_wait_for_condition(condition_fn, deadline)
      else
        {:error, :timeout}
      end
    end
  end
end
