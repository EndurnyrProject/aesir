defmodule Aesir.ZoneServer.Mmo.Combat.CriticalHits do
  @moduledoc """
  Critical hit calculation system following authentic Ragnarok Online mechanics.

  Implements the Renewal hit formula where:
  - Critical rate = LUK * 10/3 (in tenths of percent, 0-1000 scale)
  - Critical hit chance = rand(1000) < critical_rate
  - Critical damage = base_damage * 2.0
  """

  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @typedoc """
  Critical hit result containing damage and hit information.
  """
  @type critical_result :: %{
          is_critical: boolean(),
          damage: integer(),
          critical_rate: integer()
        }

  @doc """
  Calculates if an attack is a critical hit.

  Formula: critical_rate = LUK * 10/3 (capped at 1000 for 100%)
  Critical occurs when: rand(1000) < critical_rate

  ## Parameters
  - attacker_stats: The attacking unit's stats (must have LUK value)
  - base_damage: Base damage before critical multiplier

  ## Returns
  Critical result map with is_critical flag, final damage, and critical rate

  ## Examples
      iex> stats = %{luk: 30}
      iex> result = CriticalHits.calculate_critical_hit(stats, 100)
      iex> result.critical_rate
      100
      iex> result.damage >= 100
      true
  """
  @spec calculate_critical_hit(map(), integer()) :: critical_result()
  def calculate_critical_hit(attacker_stats, base_damage) when is_integer(base_damage) do
    critical_rate = calculate_critical_rate(attacker_stats)
    is_critical = is_critical_hit?(critical_rate)
    final_damage = if is_critical, do: apply_critical_damage(base_damage), else: base_damage

    %{
      is_critical: is_critical,
      damage: final_damage,
      critical_rate: critical_rate
    }
  end

  @doc """
  Calculates the critical rate.

  Formula: critical_rate = LUK * 10/3
  The result is in tenths of percent (0-1000 scale where 1000 = 100%)

  ## Parameters
  - attacker_stats: Stats map or PlayerStats struct containing LUK value

  ## Returns
  Critical rate as integer (0-1000)

  ## Examples
      iex> CriticalHits.calculate_critical_rate(%{luk: 30})
      100
      iex> CriticalHits.calculate_critical_rate(%{luk: 99})
      330
  """
  @spec calculate_critical_rate(map() | PlayerStats.t()) :: integer()
  def calculate_critical_rate(%PlayerStats{} = player_stats) do
    luk = PlayerStats.get_effective_stat(player_stats, :luk)
    calculate_critical_rate_from_luk(luk)
  end

  def calculate_critical_rate(%{luk: luk}) when is_integer(luk) do
    calculate_critical_rate_from_luk(luk)
  end

  def calculate_critical_rate(stats) when is_map(stats) do
    luk = Map.get(stats, :luk, 1)
    calculate_critical_rate_from_luk(luk)
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

  @doc """
  Applies critical damage multiplier to base damage.

  In authentic Ragnarok Online, critical hits deal exactly 2x damage.
  This is applied after all other damage calculations but before
  defense reductions.

  ## Parameters
  - base_damage: Base damage before critical multiplier

  ## Returns
  Damage multiplied by 2 for critical hits

  ## Examples
      iex> CriticalHits.apply_critical_damage(100)
      200
      iex> CriticalHits.apply_critical_damage(0)
      0
  """
  @spec apply_critical_damage(integer()) :: integer()
  def apply_critical_damage(base_damage) when is_integer(base_damage) do
    base_damage * 2
  end

  @doc """
  Calculates critical rate from raw LUK value

  Formula: critical_rate = LUK * 10/3
  Result is capped at 1000 (100% critical chance)

  ## Parameters
  - luk: LUK stat value

  ## Returns
  Critical rate as integer (0-1000)

  ## Examples
      iex> CriticalHits.calculate_critical_rate_from_luk(1)
      3
      iex> CriticalHits.calculate_critical_rate_from_luk(300)
      1000
      iex> CriticalHits.calculate_critical_rate_from_luk(999)
      1000
  """
  @spec calculate_critical_rate_from_luk(integer()) :: integer()
  def calculate_critical_rate_from_luk(luk) when is_integer(luk) do
    critical_rate = div(luk * 10, 3)
    critical_rate |> max(0) |> min(1000)
  end

  @doc """
  Checks if given stats support critical hit calculations.

  Validates that the stats contain the required LUK field
  for critical rate calculation.

  ## Parameters
  - stats: Stats map or struct to validate

  ## Returns
  Boolean indicating if critical calculations are supported

  ## Examples
      iex> CriticalHits.supports_critical?(%{luk: 50})
      true
      iex> CriticalHits.supports_critical?(%{str: 50})
      false
  """
  @spec supports_critical?(any()) :: boolean()
  def supports_critical?(%PlayerStats{}), do: true
  def supports_critical?(%{luk: luk}) when is_integer(luk), do: true
  def supports_critical?(_), do: false

  @doc """
  Gets critical hit information for display purposes.

  Returns critical rate as percentage and other useful information
  for client display or debugging.

  ## Parameters
  - attacker_stats: Stats containing LUK value

  ## Returns
  Map with critical display information

  ## Examples
      iex> info = CriticalHits.get_critical_info(%{luk: 30})
      iex> info.critical_rate
      100
      iex> info.critical_percentage
      10.0
  """
  @spec get_critical_info(map() | PlayerStats.t()) :: map()
  def get_critical_info(attacker_stats) do
    critical_rate = calculate_critical_rate(attacker_stats)

    %{
      critical_rate: critical_rate,
      critical_percentage: critical_rate / 10.0,
      max_critical_rate: 1000,
      max_critical_percentage: 100.0
    }
  end
end
