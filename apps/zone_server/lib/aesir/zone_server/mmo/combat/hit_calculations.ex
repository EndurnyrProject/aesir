defmodule Aesir.ZoneServer.Mmo.Combat.HitCalculations do
  @moduledoc """
  Hit/Miss calculation system

  This module handles accuracy vs flee calculations, perfect dodge mechanics,
  and determines whether attacks hit or miss following the authentic rAthena formulas:

  - Base hit rate: 80 + attacker.hit - target.flee
  - Perfect dodge: rand(1000) < target.perfect_dodge
  - Hit rate is clamped to 0-100% range
  """

  require Logger

  @typedoc """
  Result of a hit calculation.
  """
  @type hit_result :: :hit | :miss | :perfect_dodge

  @typedoc """
  Attacker stats required for hit calculations.
  """
  @type attacker_stats :: %{
          hit: non_neg_integer(),
          char_id: integer()
        }

  @typedoc """
  Target stats required for hit calculations.
  """
  @type target_stats :: %{
          flee: non_neg_integer(),
          perfect_dodge: non_neg_integer(),
          unit_id: integer()
        }

  @doc """
  Calculates whether an attack hits or misses

  ## Formula
  Base hit rate = 80 + attacker.hit - target.flee

  ## Priority Order
  1. Perfect dodge check (highest priority)
  2. Regular hit/miss calculation

  ## Parameters
    - attacker_stats: Map containing attacker's hit stat and char_id
    - target_stats: Map containing target's flee and perfect_dodge stats

  ## Returns
    - :hit - Attack hits normally
    - :miss - Attack misses due to insufficient hit rate
    - :perfect_dodge - Attack dodged perfectly (highest priority)

  ## Examples
      iex> attacker = %{hit: 120, char_id: 1}
      iex> target = %{flee: 0, perfect_dodge: 0, unit_id: 2}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_result(attacker, target)
      :hit

      iex> attacker = %{hit: 0, char_id: 1}
      iex> target = %{flee: 200, perfect_dodge: 0, unit_id: 2}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_result(attacker, target)
      :miss
  """
  @spec calculate_hit_result(attacker_stats(), target_stats()) :: hit_result()
  def calculate_hit_result(attacker_stats, target_stats) do
    if perfect_dodge_triggered?(target_stats) do
      Logger.debug(
        "Combat hit: Perfect dodge triggered for target #{target_stats.unit_id} (perfect_dodge: #{target_stats.perfect_dodge})"
      )

      :perfect_dodge
    else
      hit_rate = calculate_hit_rate(attacker_stats, target_stats)

      if hit_successful?(hit_rate) do
        Logger.debug(
          "Combat hit: Attack hits - attacker #{attacker_stats.char_id} vs target #{target_stats.unit_id} (hit_rate: #{hit_rate}%)"
        )

        :hit
      else
        Logger.debug(
          "Combat hit: Attack misses - attacker #{attacker_stats.char_id} vs target #{target_stats.unit_id} (hit_rate: #{hit_rate}%)"
        )

        :miss
      end
    end
  end

  @doc """
  Calculates the hit rate percentage

  ## Formula
  hit_rate = 80 + attacker.hit - target.flee

  The result is clamped to 0-100% range to prevent impossible values.

  ## Parameters
    - attacker_stats: Map containing attacker's hit stat
    - target_stats: Map containing target's flee stat

  ## Returns
    - Integer between 0 and 100 representing hit rate percentage

  ## Examples
      iex> attacker = %{hit: 120}
      iex> target = %{flee: 100}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_rate(attacker, target)
      100

      iex> attacker = %{hit: 90}
      iex> target = %{flee: 110}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_rate(attacker, target)
      60
  """
  @spec calculate_hit_rate(attacker_stats(), target_stats()) :: 0..100
  def calculate_hit_rate(attacker_stats, target_stats) do
    base_hit_rate = 80
    raw_hit_rate = base_hit_rate + attacker_stats.hit - target_stats.flee

    # Clamp to valid percentage range
    max(0, min(100, raw_hit_rate))
  end

  @doc """
  Checks if perfect dodge is triggered

  Perfect dodge uses the flee2 stat (displayed as perfect_dodge/10 in client)
  and triggers when rand(1000) < perfect_dodge value.

  ## Parameters
    - target_stats: Map containing target's perfect_dodge stat

  ## Returns
    - true if perfect dodge triggered
    - false if no perfect dodge

  ## Examples
      iex> target = %{perfect_dodge: 0}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.perfect_dodge_triggered?(target)
      false

      iex> target = %{perfect_dodge: 1000}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.perfect_dodge_triggered?(target)
      true
  """
  @spec perfect_dodge_triggered?(target_stats()) :: boolean()
  def perfect_dodge_triggered?(target_stats) do
    perfect_dodge_chance = target_stats.perfect_dodge

    # No perfect dodge possible if stat is 0
    if perfect_dodge_chance <= 0 do
      false
    else
      random_roll = :rand.uniform(1000) - 1
      random_roll < perfect_dodge_chance
    end
  end

  @spec hit_successful?(0..100) :: boolean()
  defp hit_successful?(hit_rate) do
    random_roll = :rand.uniform(100)
    random_roll <= hit_rate
  end
end
