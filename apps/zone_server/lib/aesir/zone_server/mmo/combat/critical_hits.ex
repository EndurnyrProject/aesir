defmodule Aesir.ZoneServer.Mmo.Combat.CriticalHits do
  @moduledoc """
  Critical hit calculation system following authentic Ragnarok Online mechanics.

  Natural critical chance follows the active ruleset in tenths of percent:
  - Renewal: `10 + 3 * LUK + div(base_level, 10)`
  - Classic: `10 + div(LUK * 10, 3)`
  - Critical hit chance = rand(1000) < critical_rate

  The critical damage step lives in the physical recipes and `Combat.Critical`
  rolls the chance against a defender; this module owns
  the chance only.
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @doc """
  Calculates the critical rate.

  Top-level `:critical` is an explicit tenths rate and takes precedence. A
  `combat_stats.critical_rate` snapshot is also in tenths and already includes
  equipment, status, passive and Katar contributions. A legacy
  `combat_stats.critical` is whole display percent; its discarded precision
  cannot be recovered and it is multiplied by ten only.

  Without a computed value, derives the active natural basis from LUK and
  base level. PlayerStats uses effective LUK and its progression level; raw
  maps accept `:luk` and `:base_level`, defaulting to 1 and 0 respectively.
  The result is clamped to 0-1000 (100%).

  ## Parameters
  - attacker_stats: Stats map or PlayerStats struct containing a computed
    `:critical` rate or a LUK value

  ## Returns
  Critical rate as integer (0-1000)

  ## Examples
      iex> CriticalHits.calculate_critical_rate(%{critical: 330})
      330
      iex> CriticalHits.calculate_critical_rate(%{luk: 1})
      13
  """
  @spec calculate_critical_rate(map() | PlayerStats.t()) :: integer()
  def calculate_critical_rate(%{critical: critical}) when is_integer(critical) do
    critical |> max(0) |> min(1000)
  end

  def calculate_critical_rate(%{combat_stats: %{critical_rate: rate}}) when is_integer(rate) do
    calculate_critical_rate(%{critical: rate})
  end

  def calculate_critical_rate(%{combat_stats: %{critical: display}}) when is_integer(display) do
    calculate_critical_rate(%{critical: display * 10})
  end

  def calculate_critical_rate(%PlayerStats{} = player_stats) do
    luk = PlayerStats.get_effective_stat(player_stats, :luk)
    level = Map.get(player_stats.progression || %{}, :base_level, 0)
    natural_critical_rate(luk, level)
  end

  def calculate_critical_rate(stats) when is_map(stats) do
    natural_critical_rate(Map.get(stats, :luk, 1), Map.get(stats, :base_level, 0))
  end

  @doc """
  Determines if an attack is a critical hit based on critical rate.

  Uses Elixir's :rand module to generate random number 0-999,
  then compares against critical rate (0-1000).

  ## Parameters
  - critical_rate: Critical rate in tenths of percent (0-1000)

  ## Returns
  Boolean indicating if the attack is critical

  ## Examples
      iex> CriticalHits.is_critical_hit?(0)
      false
      iex> CriticalHits.is_critical_hit?(1000)
      true
  """
  @spec is_critical_hit?(integer()) :: boolean()
  def is_critical_hit?(critical_rate) when is_integer(critical_rate) do
    random_value = :rand.uniform(1000) - 1
    random_value < critical_rate
  end

  defp natural_critical_rate(luk, base_level) do
    %{base_rate: rate} = Mechanics.player_formulas().critical(%{luk: luk, base_level: base_level})
    calculate_critical_rate(%{critical: rate})
  end
end
