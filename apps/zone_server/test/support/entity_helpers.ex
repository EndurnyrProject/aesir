defmodule Aesir.ZoneServer.EntityHelpers do
  @moduledoc """
  Helper functions for managing entities in integration tests.
  Provides utilities to spawn, manipulate, and query game entities
  including players and monsters.
  """

  alias Aesir.ZoneServer.SessionHelpers
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Spawns a quick test mob without starting a full session.
  Useful when you just need a target for testing.

  ## Options
  - :mob_id - Mob database ID
  - :hp - Current HP
  - :max_hp - Maximum HP
  - :level - Mob level

  ## Examples

      mob = spawn_test_mob("prontera", {150, 150},
                          mob_id: 1002, max_hp: 500)
  """
  def spawn_test_mob(map_name, {x, y}, opts \\ []) do
    # Use SessionHelpers to properly spawn a mob
    SessionHelpers.start_mob_session(
      Keyword.merge(opts,
        map_name: map_name,
        position: {x, y}
      )
    )
  end

  @doc """
  Spawns multiple monsters in an area for testing.

  ## Examples

      monsters = spawn_mob_group("prontera", {150, 150}, 10, 1002, 5)
      assert length(monsters) == 5
  """
  def spawn_mob_group(map_name, {center_x, center_y}, radius, mob_id, count, opts \\ []) do
    Enum.map(1..count, fn _ ->
      x = center_x + :rand.uniform(radius * 2) - radius
      y = center_y + :rand.uniform(radius * 2) - radius
      spawn_test_mob(map_name, {x, y}, Keyword.put(opts, :mob_id, mob_id))
    end)
  end

  @doc """
  Gets the current state of a unit from the registry.

  ## Examples

      state = get_unit_state(:mob, mob_id)
      assert state.hp < state.max_hp
  """
  def get_unit_state(unit_type, unit_id) do
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
  Updates a mob's HP directly.

  ## Examples

      damage_mob(mob.unit_id, 50)
  """
  def damage_mob(unit_id, damage) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} ->
        MobSession.apply_damage(pid, damage)

      _ ->
        {:error, :mob_not_found}
    end
  end

  @doc """
  Moves a unit to a new position.

  ## Examples

      move_unit(:player, player_id, 160, 170)
  """
  def move_unit(unit_type, unit_id, x, y) do
    # Get current map first
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {_old_x, _old_y, map_name}} ->
        # Update position in SpatialIndex
        SpatialIndex.update_unit_position(unit_type, unit_id, x, y, map_name)

      _ ->
        {:error, :unit_not_found}
    end
  end

  @doc """
  Removes a unit from the game world.

  ## Examples

      despawn_unit(:mob, mob_id)
  """
  def despawn_unit(unit_type, unit_id) do
    # Remove from SpatialIndex
    SpatialIndex.remove_unit(unit_type, unit_id)

    # Unregister from UnitRegistry
    case unit_type do
      :player -> UnitRegistry.unregister_player(unit_id)
      :mob -> UnitRegistry.unregister_unit(:mob, unit_id)
      _ -> :ok
    end
  end

  @doc """
  Checks if a unit exists and is alive.

  ## Examples

      assert unit_alive?(:mob, mob_id)
  """
  def unit_alive?(unit_type, unit_id) do
    case get_unit_state(unit_type, unit_id) do
      nil -> false
      %{hp: hp} when hp > 0 -> true
      _ -> false
    end
  end

  @doc """
  Gets the distance between two units.

  ## Examples

      distance = get_unit_distance({:player, player_id}, {:mob, mob_id})
      assert distance <= 5
  """
  def get_unit_distance({type1, id1}, {type2, id2}) do
    with {:ok, {x1, y1, _map1}} <- SpatialIndex.get_unit_position(type1, id1),
         {:ok, {x2, y2, _map2}} <- SpatialIndex.get_unit_position(type2, id2) do
      dx = x1 - x2
      dy = y1 - y2
      :math.sqrt(dx * dx + dy * dy)
    else
      _ -> nil
    end
  end

  @doc """
  Checks if two units are within range of each other.

  ## Examples

      assert units_in_range?({:player, player_id}, {:mob, mob_id}, 3)
  """
  def units_in_range?({type1, id1}, {type2, id2}, range) do
    distance = get_unit_distance({type1, id1}, {type2, id2})
    distance && distance <= range
  end

  @doc """
  Gets all units of a specific type on a map.

  ## Examples

      players = get_units_on_map(:player, "prontera")
  """
  def get_units_on_map(unit_type, map_name) do
    case unit_type do
      :player -> SpatialIndex.get_players_on_map(map_name)
      :mob -> SpatialIndex.get_units_on_map(:mob, map_name)
      _ -> []
    end
  end

  @doc """
  Gets units within range of a position.

  ## Examples

      nearby_mobs = get_units_in_range(:mob, "prontera", 150, 150, 10)
  """
  def get_units_in_range(unit_type, map_name, x, y, range) do
    case unit_type do
      :player -> SpatialIndex.get_players_in_range(map_name, x, y, range)
      :mob -> SpatialIndex.get_units_in_range(:mob, map_name, x, y, range)
      _ -> []
    end
  end

  @doc """
  Creates a mob with specific combat stats for testing.

  ## Examples

      boss = create_boss_mob("prontera", {200, 200},
                            hp: 10_000, level: 99)
  """
  def create_boss_mob(map_name, {x, y}, opts \\ []) do
    boss_opts =
      Keyword.merge(
        [
          # Custom boss ID
          mob_id: 1999,
          hp: 10_000,
          max_hp: 10_000,
          level: 50
        ],
        opts
      )

    spawn_test_mob(map_name, {x, y}, boss_opts)
  end

  @doc """
  Cleans up all test entities in the registry and spatial index.
  Should be called in test teardown.

  ## Examples

      cleanup_all_entities()
  """
  def cleanup_all_entities do
    # Clear UnitRegistry ETS table
    if :ets.whereis(UnitRegistry) != :undefined do
      :ets.delete_all_objects(UnitRegistry)
    end

    # Clear SpatialIndex ETS table
    if :ets.whereis(SpatialIndex) != :undefined do
      :ets.delete_all_objects(SpatialIndex)
    end

    # Also clear any map-specific spatial index tables
    ["prontera", "geffen", "morocc", "payon", "alberta"]
    |> Enum.each(fn map_name ->
      table_name = String.to_atom("spatial_index_#{map_name}")

      if :ets.whereis(table_name) != :undefined do
        :ets.delete_all_objects(table_name)
      end
    end)

    :ok
  end
end
