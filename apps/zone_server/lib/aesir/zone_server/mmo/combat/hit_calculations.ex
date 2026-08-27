defmodule Aesir.ZoneServer.Mmo.Combat.HitCalculations do
  @moduledoc """
  Hit/Miss calculation system

  This module handles accuracy vs flee calculations, perfect dodge and perfect
  hit mechanics, and determines whether attacks hit or miss:

  - Base hit rate: attacker.hit - target.flee in renewal;
    80 + attacker.hit - target.flee in pre-renewal
  - Perfect dodge: rand(1000) < target.perfect_dodge
  - Perfect hit: rand(100) < attacker.perfect_hit, ignoring the target's flee
  - Hit rate is clamped to 0-100% range, then an optional relative
    `hit_rate_bonus_pct` scales that clamped rate (e.g. a skill's own
    accuracy bonus), and the result is clamped again
  """

  alias Aesir.ZoneServer.Mmo.Mechanics

  @typedoc """
  Result of a hit calculation.
  """
  @type hit_result :: :hit | :miss | :perfect_dodge

  @typedoc """
  Attacker stats required for hit calculations.

  `perfect_hit` is the equipment-granted percent chance to bypass the accuracy
  roll; call sites that carry no equipment context may omit it and it reads
  as 0. `hit_rate_bonus_pct` is a relative percent bonus applied to the
  already-clamped base hit rate (e.g. a skill granting `+X%` accuracy for its
  own attack only); omitted call sites read as 0 (no change).
  """
  @type attacker_stats :: %{
          :hit => non_neg_integer(),
          :char_id => integer(),
          optional(:perfect_hit) => non_neg_integer(),
          optional(:hit_rate_bonus_pct) => integer()
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
  Base hit rate = mode base + attacker.hit - target.flee

  ## Priority Order
  1. Perfect dodge check (highest priority) — the defender's evasion takes
     precedence over the attacker's perfect hit
  2. Perfect hit check — bypasses the accuracy roll entirely
  3. Regular hit/miss calculation

  ## Parameters
    - attacker_stats: Map containing attacker's hit stat, char_id and optional
      perfect_hit chance
    - target_stats: Map containing target's flee and perfect_dodge stats

  ## Returns
    - :hit - Attack hits normally, or lands through a perfect hit
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
    cond do
      perfect_dodge_triggered?(target_stats) -> :perfect_dodge
      perfect_hit_triggered?(attacker_stats) -> :hit
      hit_successful?(calculate_hit_rate(attacker_stats, target_stats)) -> :hit
      true -> :miss
    end
  end

  @doc """
  Calculates the hit rate percentage

  ## Formula
  hit_rate = mode_base + attacker.hit - target.flee

  The mode base is `0` in renewal and `80` in pre-renewal.

  The result is clamped to 0-100% range to prevent impossible values, then
  scaled by the attacker's optional `hit_rate_bonus_pct` (a relative percent
  bonus applied to that clamped rate, not to the raw `hit` stat — e.g. a
  skill's own `+5%` per level accuracy bonus) and clamped again.

  ## Parameters
    - attacker_stats: Map containing attacker's hit stat and optional
      hit_rate_bonus_pct
    - target_stats: Map containing target's flee stat

  ## Returns
    - Integer between 0 and 100 representing hit rate percentage

  ## Examples
      iex> attacker = %{hit: 220}
      iex> target = %{flee: 100}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_rate(attacker, target)
      100

      iex> attacker = %{hit: 170}
      iex> target = %{flee: 110}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_rate(attacker, target)
      60

      iex> attacker = %{hit: 180, hit_rate_bonus_pct: 50}
      iex> target = %{flee: 150}
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.calculate_hit_rate(attacker, target)
      45
  """
  @spec calculate_hit_rate(attacker_stats(), target_stats()) :: 0..100
  def calculate_hit_rate(attacker_stats, target_stats) do
    raw_hit_rate =
      Mechanics.player_formulas().hit_rate_base() + attacker_stats.hit - target_stats.flee

    clamped_hit_rate = max(0, min(100, raw_hit_rate))

    bonus_pct = Map.get(attacker_stats, :hit_rate_bonus_pct, 0)
    scaled_hit_rate = div(clamped_hit_rate * (100 + bonus_pct), 100)

    max(0, min(100, scaled_hit_rate))
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

  @doc """
  Checks if a perfect hit is triggered.

  A perfect hit makes the attack land regardless of the accuracy roll, ignoring
  the target's flee entirely. The chance is the attacker's equipment-granted
  percent `perfect_hit` value and triggers when rand(100) < that value.

  Attackers without the key — mobs and any call site with no equipment context
  — never trigger it.

  ## Examples
      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.perfect_hit_triggered?(%{hit: 10})
      false

      iex> Aesir.ZoneServer.Mmo.Combat.HitCalculations.perfect_hit_triggered?(%{perfect_hit: 100})
      true
  """
  @spec perfect_hit_triggered?(attacker_stats()) :: boolean()
  def perfect_hit_triggered?(attacker_stats) do
    perfect_hit_chance = Map.get(attacker_stats, :perfect_hit, 0)

    if perfect_hit_chance <= 0 do
      false
    else
      random_roll = :rand.uniform(100) - 1
      random_roll < perfect_hit_chance
    end
  end

  @spec hit_successful?(0..100) :: boolean()
  defp hit_successful?(hit_rate) do
    random_roll = :rand.uniform(100)
    random_roll <= hit_rate
  end
end
