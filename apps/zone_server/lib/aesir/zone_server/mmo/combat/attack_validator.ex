defmodule Aesir.ZoneServer.Mmo.Combat.AttackValidator do
  @moduledoc """
  Pre-attack validation between two combatants: same map, attack range, and
  projectile line of sight.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight

  @doc """
  Validates an attack between two combatants.

  Checks same-map, attack range (skipped with `:skip_range` for casts whose
  skill range the interpreter already validated), and — with `:projectile?` and
  a ranged attacker — an unobstructed projectile path.
  """
  @spec validate(map(), map(), keyword()) :: :ok | {:error, atom()}
  def validate(attacker, target, opts) do
    with :ok <- validate_same_map(attacker, target),
         :ok <- validate_attack_distance(attacker, target, opts) do
      validate_projectile_path(attacker, target, opts)
    end
  end

  @doc """
  Validates a mob's attack on its target.

  Ranged mob attacks (attack_range > 1) respect terrain the same way player
  ranged autos do: a wall between attacker and target blocks the shot (rAthena
  `battle_check_range` path-searches once the target is not adjacent). Melee
  mobs (attack_range == 1) can only reach adjacent cells, so the seam is a no-op
  for them.
  """
  @spec validate_mob_attack(map(), map()) :: :ok | {:error, atom()}
  def validate_mob_attack(attacker, target) do
    with :ok <- validate_attack_range(attacker, target) do
      validate_projectile_path(attacker, target, projectile?: true)
    end
  end

  defp validate_same_map(%{map_name: map_name}, %{map_name: map_name}), do: :ok
  defp validate_same_map(_attacker, _target), do: {:error, :different_map}

  defp validate_attack_distance(attacker, target, opts) do
    if Keyword.get(opts, :skip_range, false),
      do: :ok,
      else: validate_attack_range(attacker, target)
  end

  defp validate_projectile_path(attacker, target, opts) do
    if Keyword.get(opts, :projectile?, false) and attacker.attack_range > 1 do
      validate_projectile_line(attacker, target)
    else
      :ok
    end
  end

  defp validate_projectile_line(attacker, target) do
    if LineOfSight.clear?(attacker.map_name, attacker.position, target.position) do
      :ok
    else
      {:error, :projectile_blocked}
    end
  end

  defp validate_attack_range(attacker, target) do
    attack_range = attacker.attack_range
    {attacker_x, attacker_y} = attacker.position
    {target_x, target_y} = target.position

    distance = Geometry.chebyshev_distance(attacker_x, attacker_y, target_x, target_y)

    if distance <= attack_range do
      :ok
    else
      Logger.debug(
        "Attack failed: target out of range (distance: #{distance}, max: #{attack_range})"
      )

      {:error, :target_out_of_range}
    end
  end
end
