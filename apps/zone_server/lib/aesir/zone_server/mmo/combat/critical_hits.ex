defmodule Aesir.ZoneServer.Mmo.Combat.CriticalHits do
  @moduledoc """
  Critical hit calculation system following authentic Ragnarok Online mechanics.

  Natural critical chance follows the active ruleset in tenths of percent:
  - Renewal: `10 + 3 * LUK + div(base_level, 10)`
  - Classic: `10 + div(LUK * 10, 3)`
  - Critical hit chance = rand(1000) < critical_rate
  - Critical damage = base_damage * (1.4 + 0.01 * CRate)
  """

  alias Aesir.ZoneServer.Mmo.Mechanics
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

  Uses the computed rate or active natural critical basis, capped at 1000 (100%).
  Critical occurs when: rand(1000) < critical_rate

  ## Parameters
  - attacker_stats: The attacking unit's stats (must have LUK value)
  - base_damage: Base damage before critical multiplier

  ## Returns
  Critical result map with is_critical flag, final damage, and critical rate

  ## Examples
      iex> stats = %{critical: 100}
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

    final_damage =
      if is_critical, do: apply_critical_damage(base_damage, attacker_stats), else: base_damage

    %{
      is_critical: is_critical,
      damage: final_damage,
      critical_rate: critical_rate
    }
  end

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

  @doc """
  Applies the Renewal critical damage multiplier to base damage.

  Renewal critical damage is `1.4 + 0.01 * CRate` of base damage, where CRate
  is the attacker's `combat_stats.crate` slot. Attackers without a `crate`
  slot (e.g. mobs) default to 0, landing on the flat `x1.4` factor.

  Equipment-granted critical damage (`equip_modifiers.crit_atk_rate`) is a
  separate percent step applied over that factor, never folded into CRate: the
  two are distinct channels and must not compound inside the same accumulator.
  Because the step lives here, it only ever reaches damage that already rolled
  a critical.

  ## Parameters
  - base_damage: Base damage before critical multiplier
  - attacker: Stats map or struct; `combat_stats.crate` supplies CRate (default 0)
    and `equip_modifiers.crit_atk_rate` the equipment percent (default 0)

  ## Returns
  Damage multiplied by the Renewal critical factor and the equipment critical
  damage percent, truncated to an integer

  ## Examples
      iex> CriticalHits.apply_critical_damage(1000, %{})
      1400
      iex> CriticalHits.apply_critical_damage(1000, %{combat_stats: %{crate: 30}})
      1700
      iex> CriticalHits.apply_critical_damage(1000, %{equip_modifiers: %{crit_atk_rate: 50}})
      2100
  """
  @spec apply_critical_damage(integer(), map() | PlayerStats.t()) :: integer()
  def apply_critical_damage(base_damage, attacker) when is_integer(base_damage) do
    crate = crate_from(attacker)

    base_damage
    |> Kernel.*(1.4 + 0.01 * crate)
    |> trunc()
    |> apply_crit_atk_rate(crit_atk_rate_from(attacker))
  end

  defp apply_crit_atk_rate(damage, 0), do: damage
  defp apply_crit_atk_rate(damage, rate), do: div(damage * (100 + rate), 100)

  defp crate_from(attacker) do
    case Map.get(attacker, :combat_stats) do
      %{crate: crate} when is_integer(crate) -> crate
      _ -> 0
    end
  end

  defp crit_atk_rate_from(attacker) do
    case Map.get(attacker, :equip_modifiers) do
      %{crit_atk_rate: rate} when is_integer(rate) -> rate
      _ -> 0
    end
  end

  defp natural_critical_rate(luk, base_level) do
    %{base_rate: rate} = Mechanics.player_formulas().critical(%{luk: luk, base_level: base_level})
    calculate_critical_rate(%{critical: rate})
  end
end
