defmodule Aesir.ZoneServer.Mmo.Skill.Targeting do
  @moduledoc """
  Shared enemy-target relation for skills and combat.

  A living mob is an enemy. A living player is an enemy unless it is the
  caster or shares the caster's nonzero party or guild. This is deliberately
  only a relation check; map-mode-specific PvP policy can be layered here when
  the server gains one.
  """

  @doc """
  Validates that `target` is a living enemy of `attacker`.
  """
  @spec validate_enemy(map(), map()) :: :ok | {:error, :invalid_target | :target_dead}
  def validate_enemy(attacker, target) do
    cond do
      not alive?(target) -> {:error, :target_dead}
      same_unit?(attacker, target) -> {:error, :invalid_target}
      allied_players?(attacker, target) -> {:error, :invalid_target}
      true -> :ok
    end
  end

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
