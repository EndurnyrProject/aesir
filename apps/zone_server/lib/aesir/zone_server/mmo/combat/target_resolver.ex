defmodule Aesir.ZoneServer.Mmo.Combat.TargetResolver do
  @moduledoc """
  Resolves combat target ids to their live unit state, combatant, and position.

  The one place that knows how players, mobs, and targetable skill units are
  stored (registry, spatial index, session state), so the attack paths can stay
  free of storage details. Bare-id lookups resolve players before mobs when ids
  collide.
  """

  require Logger

  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "A resolved live target: owning pid, unit state, and unit type."
  @type resolved :: {:ok, pid(), struct(), :player | :mob | :skill_unit}

  @doc """
  Resolves a target's type and authoritative spatial position.

  Player IDs take precedence over mob IDs when they collide.
  """
  @spec resolve_target_position(integer()) ::
          {:ok, :player | :mob | :skill_unit, {integer(), integer(), String.t()}}
          | {:error, :target_not_found}
  def resolve_target_position(target_id) do
    if CombatTarget.target?(target_id) do
      CombatTarget.resolve_position(target_id)
    else
      resolve_standard_target_position(target_id)
    end
  end

  @doc """
  Resolves a unit id to its combatant struct.

  Returns `{:error, reason}` when the unit is gone (logged out, despawned), so
  the caller can skip cleanly.
  """
  @spec resolve_combatant(integer()) :: {:ok, struct()} | {:error, atom()}
  def resolve_combatant(unit_id) do
    with {:ok, _pid, state, _type} <- resolve(unit_id) do
      {:ok, state.__struct__.to_combatant(state)}
    end
  end

  @doc """
  Resolves a bare target id to its live unit state.

  Targetable skill units are recognized by their id range; otherwise players
  are tried before mobs.
  """
  @spec resolve(integer()) :: resolved() | {:error, atom()}
  def resolve(target_id) do
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

  @doc """
  Resolves a target id of a known unit type to its live unit state.
  """
  @spec resolve(atom(), integer()) :: resolved() | {:error, atom()}
  def resolve(:mob, target_id), do: get_mob_unit_state(target_id)
  def resolve(:player, target_id), do: get_player_unit_state(target_id)
  def resolve(:skill_unit, target_id), do: CombatTarget.resolve(target_id)

  @doc """
  Gates out targets that cannot be hit: dead mobs and players, destroyed skill
  units.

  The melee path resolves the full unit state, so this is the authoritative
  gate; `MobSession` independently drops damage to dead mobs.
  """
  @spec ensure_targetable(struct() | map(), :player | :mob | :skill_unit) ::
          :ok | {:error, :target_dead}
  def ensure_targetable(%{is_dead: true}, :mob), do: {:error, :target_dead}
  def ensure_targetable(%{hp: hp}, :mob) when hp <= 0, do: {:error, :target_dead}
  def ensure_targetable(_target_state, :mob), do: :ok
  def ensure_targetable(%{action_state: :dead}, :player), do: {:error, :target_dead}
  def ensure_targetable(_target_state, :player), do: :ok
  def ensure_targetable(%{hp: hp}, :skill_unit) when hp > 0, do: :ok
  def ensure_targetable(_target_state, :skill_unit), do: {:error, :target_dead}

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
    case get_mob_unit_state(target_id) do
      {:error, :not_found} -> {:error, :target_not_found}
      result -> result
    end
  end

  defp get_mob_unit_state(target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, mob_state, pid}} when is_pid(pid) ->
        # Get the current position from SpatialIndex for consistency
        updated_mob_state =
          case SpatialIndex.get_unit_position(:mob, target_id) do
            {:ok, {x, y, _map}} ->
              %{mob_state | x: x, y: y}

            _ ->
              mob_state
          end

        {:ok, pid, updated_mob_state, :mob}

      {:error, :not_found} ->
        Logger.warning("Mob #{target_id} not found in registry")
        {:error, :not_found}

      {:ok, {_module, _state, nil}} ->
        Logger.warning("Mob #{target_id} found but has no pid")
        {:error, :target_no_pid}
    end
  end

  defp get_player_unit_state(target_id) do
    case UnitRegistry.get_player_pid(target_id) do
      {:ok, pid} ->
        stats = PlayerSession.get_current_stats(pid)
        session_state = PlayerSession.get_state(pid)
        # Extract the game_state which is the actual PlayerState
        player_state = session_state.game_state
        # Update player state with current stats for combat
        player_state = %{player_state | stats: stats}
        {:ok, pid, player_state, :player}

      {:error, :not_found} ->
        Logger.warning("Target #{target_id} not found in registry")
        {:error, :target_not_found}
    end
  end
end
