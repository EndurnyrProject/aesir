defmodule Aesir.ZoneServer.Mmo.Skill.Interpreter do
  @moduledoc """
  Orchestrates a skill cast: resolve definition + behavior, validate the cast,
  check SP, dispatch to the behavior, then deduct SP.

  Validate-then-cast-then-charge: SP is only consumed after the behavior
  succeeds, so a failed cast never charges SP.
  """
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviour
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cooldown
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @spec cast(PlayerState.t(), integer(), pos_integer(), Behaviour.target()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(game_state, skill_id, level, target) when is_integer(level) and level > 0 do
    now = System.monotonic_time(:millisecond)

    with {:ok, definition} <- fetch_definition(skill_id),
         :ok <- check_max_level(definition, level),
         :ok <- check_castable(definition),
         :ok <- check_learned(game_state, skill_id, level),
         :ok <- check_target(game_state, target, definition),
         :ok <- check_range(game_state, target, definition),
         {:ok, module} <- fetch_behavior(definition),
         :ok <- check_cooldown(game_state, skill_id, now),
         :ok <- module.validate(game_state, target, level, definition),
         cost = Enum.at(definition.sp_cost, level - 1),
         :ok <- check_sp(game_state, cost),
         {:ok, game_state} <- module.cast(game_state, target, level, definition) do
      {:ok, game_state |> deduct_sp(cost) |> put_cooldown(skill_id, definition, level, now)}
    end
  end

  def cast(_game_state, _skill_id, _level, _target), do: {:error, :invalid_level}

  defp fetch_definition(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, definition} -> {:ok, definition}
      :error -> {:error, :unknown_skill}
    end
  end

  defp check_max_level(definition, level) when level <= definition.max_level, do: :ok
  defp check_max_level(_definition, _level), do: {:error, :invalid_level}

  defp check_castable(%{target_type: :passive}), do: {:error, :passive_skill}
  defp check_castable(_definition), do: :ok

  defp fetch_behavior(definition) do
    case Behaviors.module_for(definition.name) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :no_behavior}
    end
  end

  defp check_learned(game_state, skill_id, level) do
    learned = game_state.stats.progression.learned_skills

    if Learned.learned_level(learned, skill_id) >= level do
      :ok
    else
      {:error, :skill_not_learned}
    end
  end

  # Enemy skills target another unit; support skills are self-cast only for now.
  # TODO: ally targeting still comes next.
  defp check_target(%{character_id: caster_id}, {:unit, caster_id}, %{target_type: :target_enemy}),
       do: {:error, :invalid_target}

  defp check_target(_game_state, {:unit, _id}, %{target_type: :target_enemy}), do: :ok

  defp check_target(_game_state, {:ground, _x, _y}, %{target_type: :ground}), do: :ok

  defp check_target(_game_state, :self, _definition), do: :ok
  defp check_target(%{character_id: caster_id}, {:unit, caster_id}, _definition), do: :ok
  defp check_target(_game_state, _target, _definition), do: {:error, :invalid_target}

  defp check_range(_game_state, :self, _definition), do: :ok

  defp check_range(game_state, {:unit, target_id}, definition) do
    case resolve_unit_position(target_id) do
      {:ok, {tx, ty, _map}} ->
        if Geometry.chebyshev_distance(game_state.x, game_state.y, tx, ty) <= definition.range,
          do: :ok,
          else: {:error, :out_of_range}

      {:error, _} ->
        {:error, :target_not_found}
    end
  end

  defp check_range(game_state, {:ground, x, y}, definition) do
    with :ok <- check_ground_range(game_state, x, y, definition) do
      check_ground_walkable(game_state.map_name, x, y)
    end
  end

  defp check_ground_range(game_state, x, y, definition) do
    if Geometry.chebyshev_distance(game_state.x, game_state.y, x, y) <= definition.range,
      do: :ok,
      else: {:error, :out_of_range}
  end

  defp check_ground_walkable(map_name, x, y) do
    with {:ok, map} <- MapCache.get(map_name),
         true <- MapData.walkable?(map, x, y) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  defp resolve_unit_position(unit_id) do
    case SpatialIndex.get_unit_position(:player, unit_id) do
      {:ok, _} = result -> result
      {:error, :not_found} -> SpatialIndex.get_unit_position(:mob, unit_id)
    end
  end

  defp check_cooldown(game_state, skill_id, now) do
    if Cooldown.ready?(game_state.skill_cooldowns, skill_id, now) do
      :ok
    else
      {:error, :on_cooldown}
    end
  end

  defp check_sp(game_state, cost) do
    if game_state.stats.current_state.sp >= cost, do: :ok, else: {:error, :insufficient_sp}
  end

  # Player SP lives in the nested current_state; mutate it inline (same pattern
  # as HealthHandler), since consume_sp is defined on Unit.Stats, not Player.Stats.
  defp deduct_sp(game_state, cost) do
    stats = game_state.stats
    current = %{stats.current_state | sp: stats.current_state.sp - cost}
    %{game_state | stats: %{stats | current_state: current}}
  end

  defp put_cooldown(game_state, skill_id, definition, level, now) do
    case Cooldown.duration(definition, level) do
      0 ->
        game_state

      duration ->
        cooldowns = Cooldown.put(game_state.skill_cooldowns, skill_id, now + duration)
        %{game_state | skill_cooldowns: cooldowns}
    end
  end
end
