defmodule Aesir.ZoneServer.Mmo.Skill.Targeting do
  @moduledoc """
  Shared enemy-target relation for skills and combat.

  A living mob is an enemy. A living player is an enemy of a mob. A player,
  however, is never a valid target for another player until the server gains
  PvP map modes: `pvp_enabled?/1` is the single seam that flips that policy.
  Beyond PvP, players sharing the caster's nonzero party or guild are never
  enemies.
  """

  @doc """
  Validates that `target` is a living enemy of `attacker`.
  """
  @spec validate_enemy(map(), map()) :: :ok | {:error, :invalid_target | :target_dead}
  def validate_enemy(attacker, target) do
    cond do
      not alive?(target) -> {:error, :target_dead}
      same_unit?(attacker, target) -> {:error, :invalid_target}
      pvp_blocked?(attacker, target) -> {:error, :invalid_target}
      allied_players?(attacker, target) -> {:error, :invalid_target}
      true -> :ok
    end
  end

  # A player attacking another player is rejected until PvP map modes exist.
  # Mob-vs-player and player-vs-mob are unaffected because at least one side is
  # not a player. Flipping `pvp_enabled?/1` to true reopens player-vs-player and
  # hands the alliance decision to `allied_players?/2`.
  defp pvp_blocked?(attacker, target) do
    unit_type(attacker) == :player and unit_type(target) == :player and
      not pvp_enabled?(attacker)
  end

  defp pvp_enabled?(_attacker), do: false

  defp same_unit?(attacker, target) do
    unit_type(attacker) == unit_type(target) and unit_id(attacker) == unit_id(target)
  end

  defp allied_players?(attacker, target) do
    unit_type(attacker) == :player and unit_type(target) == :player and
      (same_nonzero?(attacker, target, :party_id) or
         same_nonzero?(attacker, target, :guild_id))
  end

  defp same_nonzero?(attacker, target, key) do
    value = Map.get(attacker, key, 0)
    value != 0 and value == Map.get(target, key, 0)
  end

  defp alive?(%{is_dead: true}), do: false
  defp alive?(%{action_state: :dead}), do: false
  defp alive?(%{hp: hp}) when hp <= 0, do: false
  defp alive?(%{stats: %{current_state: %{hp: hp}}}) when hp <= 0, do: false
  defp alive?(_target), do: true

  defp unit_type(%{unit_type: unit_type}), do: unit_type
  defp unit_type(%{character_id: _character_id}), do: :player
  defp unit_type(%{instance_id: _instance_id}), do: :mob

  defp unit_id(%{unit_id: unit_id}), do: unit_id
  defp unit_id(%{character_id: character_id}), do: character_id
  defp unit_id(%{instance_id: instance_id}), do: instance_id
end
