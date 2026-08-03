defmodule Aesir.ZoneServer.Mmo.Combat.TargetResolver do
  @moduledoc """
  Resolves typed combat targets to their live unit state, combatant, and position.

  Bare IDs remain supported for legacy player/mob/skill-unit callers. They never
  resolve Homunculi: callers targeting a companion must supply a `Unit.Ref`.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "A resolved live target: owning pid, unit state, and unit type."
  @type target_type :: :player | :mob | :homunculus | :skill_unit
  @type target :: integer() | Ref.t()
  @type resolved :: {:ok, pid(), struct(), target_type()}

  @doc """
  Resolves a target's type and authoritative spatial position.

  A typed reference is exact. Legacy bare IDs preserve player-before-mob
  precedence and reserved skill-unit ID handling.
  """
  @spec resolve_target_position(target()) ::
          {:ok, target_type(), {integer(), integer(), String.t()}}
          | {:error, :target_not_found}
  def resolve_target_position({unit_type, unit_id} = ref) do
    if Ref.valid?(ref) do
      resolve_typed_position(unit_type, unit_id)
    else
      {:error, :target_not_found}
    end
  end

  def resolve_target_position(target_id) when is_integer(target_id) do
    if CombatTarget.target?(target_id) do
      CombatTarget.resolve_position(target_id)
    else
      resolve_standard_target_position(target_id)
    end
  end

  @doc """
  Resolves a target to its combatant struct.

  Homunculi require a typed reference; bare IDs retain legacy resolution.
  """
  @spec resolve_combatant(target()) :: {:ok, struct()} | {:error, atom()}
  def resolve_combatant(target) do
    with {:ok, _pid, state, _type} <- resolve(target) do
      {:ok, state.__struct__.to_combatant(state)}
    end
  end

  @doc "Resolves a known unit type and id to its combatant struct."
  @spec resolve_combatant(target_type(), integer()) :: {:ok, struct()} | {:error, atom()}
  def resolve_combatant(unit_type, unit_id) do
    with {:ok, _pid, state, ^unit_type} <- resolve(unit_type, unit_id) do
      {:ok, state.__struct__.to_combatant(state)}
    end
  end

  @doc """
  Resolves a target to its live unit state.

  Typed references are exact and collision-safe. A bare target ID never probes
  the Homunculus registry.
  """
  @spec resolve(target()) :: resolved() | {:error, atom()}
  def resolve({unit_type, unit_id} = ref) do
    if Ref.valid?(ref) and unit_type in [:player, :mob, :homunculus, :skill_unit],
      do: resolve(unit_type, unit_id),
      else: {:error, :target_not_found}
  end

  def resolve(target_id) when is_integer(target_id) do
    if CombatTarget.target?(target_id) do
      CombatTarget.resolve(target_id)
    else
      case get_player_unit_state(target_id) do
        {:ok, pid, player_state, :player} ->
          {:ok, pid, player_state, :player}

        {:error, :target_not_found} ->
          get_standard_mob_unit_state(target_id)
      end
    end
  end

  @doc "Resolves an exact unit type and id to its live unit state."
  @spec resolve(target_type(), integer()) :: resolved() | {:error, atom()}
  def resolve(:mob, target_id), do: get_registered_unit_state(:mob, target_id)
  def resolve(:homunculus, target_id), do: get_registered_unit_state(:homunculus, target_id)
  def resolve(:player, target_id), do: get_player_unit_state(target_id)
  def resolve(:skill_unit, target_id), do: CombatTarget.resolve(target_id)

  @doc "Gates out dead units and destroyed skill-unit cells."
  @spec ensure_targetable(struct() | map(), target_type()) :: :ok | {:error, :target_dead}
  def ensure_targetable(target_state, unit_type)
      when unit_type in [:player, :mob, :homunculus] do
    if Unit.living?(target_state), do: :ok, else: {:error, :target_dead}
  end

  def ensure_targetable(%{hp: hp}, :skill_unit) when hp > 0, do: :ok
  def ensure_targetable(_target_state, :skill_unit), do: {:error, :target_dead}

  defp resolve_typed_position(:skill_unit, target_id),
    do: CombatTarget.resolve_position(target_id)

  defp resolve_typed_position(unit_type, target_id)
       when unit_type in [:player, :mob, :homunculus] do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, position} -> {:ok, unit_type, position}
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end

  defp resolve_typed_position(_unit_type, _target_id), do: {:error, :target_not_found}

  defp resolve_standard_target_position(target_id) do
    case SpatialIndex.get_unit_position(:player, target_id) do
      {:ok, position} -> {:ok, :player, position}
      {:error, :not_found} -> resolve_mob_target_position(target_id)
    end
  end

  defp resolve_mob_target_position(target_id) do
    case SpatialIndex.get_unit_position(:mob, target_id) do
      {:ok, position} -> {:ok, :mob, position}
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end

  defp get_standard_mob_unit_state(target_id) do
    case get_registered_unit_state(:mob, target_id) do
      {:error, :not_found} -> {:error, :target_not_found}
      result -> result
    end
  end

  defp get_registered_unit_state(unit_type, target_id) do
    case UnitRegistry.get_unit(unit_type, target_id) do
      {:ok, {_module, state, pid}} when is_pid(pid) ->
        {:ok, pid, current_position(state, unit_type, target_id), unit_type}

      {:error, :not_found} ->
        Logger.debug("#{unit_type} #{target_id} not found in registry")
        {:error, :not_found}

      {:ok, {_module, _state, nil}} ->
        Logger.debug("#{unit_type} #{target_id} found but has no pid")
        {:error, :target_no_pid}
    end
  end

  defp current_position(state, unit_type, target_id) do
    case SpatialIndex.get_unit_position(unit_type, target_id) do
      {:ok, {x, y, _map}} -> %{state | x: x, y: y}
      _ -> state
    end
  end

  defp get_player_unit_state(target_id) do
    case UnitRegistry.get_player_pid(target_id) do
      {:ok, pid} -> get_player_snapshot(target_id, pid)
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end

  defp get_player_snapshot(target_id, pid) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, player_state, _pid}} -> {:ok, pid, player_state, :player}
      {:error, :not_found} -> {:error, :target_not_found}
    end
  end
end
