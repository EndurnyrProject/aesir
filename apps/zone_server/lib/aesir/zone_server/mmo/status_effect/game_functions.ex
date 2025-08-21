defmodule Aesir.ZoneServer.Mmo.StatusEffect.GameFunctions do
  @moduledoc """
  Registry of custom game functions available in status effect formulas.

  These functions provide access to game mechanics and player data
  that can be called from within formula strings.
  """

  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  require Logger

  @doc """
  Returns the registry of available custom functions.
  Maps function names (as strings) to {module, function, arity} tuples.
  The arity represents the number of arguments in the formula, 
  not including the context which is automatically injected.
  """
  def registry do
    %{
      "pc_checkskill" => {__MODULE__, :pc_checkskill, 2},
      "has_status" => {__MODULE__, :has_status, 2},
      "has_status/1" => {__MODULE__, :has_status, 1},
      "get_skill_level" => {__MODULE__, :get_skill_level, 2},
      "is_equipped" => {__MODULE__, :is_equipped, 2},
      "job_level" => {__MODULE__, :job_level, 1},
      "base_level" => {__MODULE__, :base_level, 1},
      "random" => {__MODULE__, :random, 2},
      "pc_check_weapontype" => {__MODULE__, :pc_check_weapontype, 2}
    }
  end

  @doc """
  Check if a target has a specific skill at a minimum level.
  Returns the skill level if >= required level, 0 otherwise.

  ## Examples
      pc_checkskill(caster, :rg_tunneldrive)
      pc_checkskill(target, :as_poisonreact)
  """
  def pc_checkskill(context, target_selector, skill_id) do
    # Handle both atom and string skill IDs
    skill_id = if is_binary(skill_id), do: String.to_atom(skill_id), else: skill_id
    target_id = resolve_target_id(context, target_selector)

    case get_player_skill_level(target_id, skill_id) do
      nil -> 0
      level -> level
    end
  end

  @doc """
  Check if a target has a specific status effect active.
  Returns 1 if active, 0 otherwise.

  Supports two calling patterns:
  - has_status(target, status_id) - Checks if target has status
  - has_status(status_id) - Checks if current target has status (used in conditions)
  """
  def has_status(context, target_selector, status_id) do
    target_id = resolve_target_id(context, target_selector)
    check_status(context, target_id, status_id)
  end

  @doc """
  Check if the target has a specific status effect active.
  This is an overload that assumes the target is the current target (used in condition formulas).

  Returns 1 if active, 0 otherwise.
  """
  def has_status(context, status_id) do
    # When called with one parameter in a formula, we assume the target is the current target
    target_id = Map.get(context, :target_id)
    check_status(context, target_id, status_id)
  end

  # Helper function for status checking to avoid code duplication
  defp check_status(_context, target_id, status_id) do
    # TODO: Implement proper status checking when integration is complete
    # This is a stub implementation that always returns 0 (false)
    # In the future, use StatusStorage.has_status? to actually check

    # Normalize status_id to atom if it's a string
    status_id = if is_binary(status_id), do: String.to_atom(status_id), else: status_id

    _ = {target_id, status_id}
    0
  end

  @doc """
  Get the level of a specific skill for a target.
  Returns 0 if the skill is not learned.
  """
  def get_skill_level(context, target_selector, skill_id) do
    target_id = resolve_target_id(context, target_selector)

    case get_player_skill_level(target_id, skill_id) do
      nil -> 0
      level -> level
    end
  end

  @doc """
  Check if a target has a specific item equipped.
  Returns 1 if equipped, 0 otherwise.
  """
  def equipped?(context, target_selector, item_id) do
    target_id = resolve_target_id(context, target_selector)

    # TODO: Check equipment slots for item
    # For now, return 0
    _ = {target_id, item_id}
    0
  end

  @doc """
  Get the job level of a target.
  """
  def job_level(context, target_selector) do
    target_id = resolve_target_id(context, target_selector)

    case get_player_stats(target_id) do
      %{job_level: level} -> level
      _ -> 1
    end
  end

  @doc """
  Get the base level of a target.
  """
  def base_level(context, target_selector) do
    target_id = resolve_target_id(context, target_selector)

    case get_player_stats(target_id) do
      %{base_level: level} -> level
      _ -> 1
    end
  end

  @doc """
  Generate a random number between min and max (inclusive).
  """
  def random(_context, min, max) when is_number(min) and is_number(max) do
    trunc(min + :rand.uniform() * (max - min + 1))
  end

  @doc """
  Check if a target is using a specific weapon type or any in a list of weapon types.
  Returns 1 if the player is using one of the specified weapon types, 0 otherwise.

  ## Examples
      pc_check_weapontype(target, :dagger)
      pc_check_weapontype(target, [:axe, :mace])
  """
  def pc_check_weapontype(context, target_selector, weapon_types) do
    target_id = resolve_target_id(context, target_selector)

    # TODO: Implement proper weapon type checking when equipment system is available
    # This is a stub implementation that always returns 0 (false)
    # In the future, this should:
    # 1. Get the player's current equipped weapon from equipment system
    # 2. Check if the weapon type matches any in the list
    # 3. Return 1 if matched, 0 otherwise

    _ = {target_id, weapon_types}
    0
  end

  # Private helper functions

  defp resolve_target_id(context, :target), do: Map.get(context, :target_id)
  defp resolve_target_id(context, :caster), do: Map.get(context, :caster_id)
  defp resolve_target_id(context, :source), do: Map.get(context, :caster_id)
  defp resolve_target_id(_context, id) when is_binary(id), do: id
  defp resolve_target_id(_context, _), do: nil

  defp get_player_skill_level(nil, _skill_id), do: 0

  defp get_player_skill_level(player_id, skill_id) do
    # TODO: Query PlayerSession for actual skill data
    # For now, return a stub value
    case PlayerSession.get_state(player_id) do
      {:ok, state} ->
        # Assuming skills are stored in state.skills as a map
        Map.get(state.skills || %{}, skill_id, 0)

      _ ->
        Logger.debug("Could not get skill level for player #{player_id}, skill #{skill_id}")
        0
    end
  rescue
    _ -> 0
  end

  defp get_player_stats(nil), do: %{}

  defp get_player_stats(player_id) do
    # TODO: Query PlayerSession for actual stats
    case PlayerSession.get_state(player_id) do
      {:ok, state} ->
        state.stats || %{}

      _ ->
        Logger.debug("Could not get stats for player #{player_id}")
        %{}
    end
  rescue
    _ -> %{}
  end
end
