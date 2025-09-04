defmodule Aesir.ZoneServer.Mmo.Combat.AttackSpeed do
  @moduledoc """
  Calculates attack delays from ASPD values following authentic Ragnarok Online mechanics.

  This module converts ASPD (Attack Speed) values into actual attack delay times in milliseconds,
  which are used by the combat system to enforce proper attack rate limiting.

  Renewal formula:
  - ASPD is displayed as: 200 - (delay / 10)
  - The actual attack delay in milliseconds is: (200 - ASPD) * 10
  - ASPD ranges from 0 (slowest) to 193 (fastest)
  """

  @doc """
  Calculates the attack delay in milliseconds from an ASPD value.

  ## Parameters
    - aspd: The ASPD value (0-193, where higher is faster)

  ## Returns
    - Attack delay in milliseconds

  ## Examples
      iex> AttackSpeed.calculate_delay(150)
      500

      iex> AttackSpeed.calculate_delay(193)
      70

      iex> AttackSpeed.calculate_delay(100)
      1000
  """
  @spec calculate_delay(integer()) :: integer()
  def calculate_delay(aspd) when aspd >= 0 and aspd <= 193 do
    (200 - aspd) * 10
  end

  def calculate_delay(aspd) when aspd > 193 do
    # Cap at max ASPD (193)
    calculate_delay(193)
  end

  def calculate_delay(aspd) when aspd < 0 do
    # Cap at min ASPD (0)
    calculate_delay(0)
  end

  @doc """
  Calculates the attack delay from player stats.

  ## Parameters
    - stats: Player stats struct containing derived_stats.aspd

  ## Returns
    - Attack delay in milliseconds
  """
  @spec calculate_delay_from_stats(map()) :: integer()
  def calculate_delay_from_stats(%{derived_stats: %{aspd: aspd}}) do
    calculate_delay(aspd)
  end

  @doc """
  Checks if enough time has passed since the last attack.

  ## Parameters
    - last_attack_timestamp: Timestamp of the last attack in milliseconds
    - attack_delay: Required delay between attacks in milliseconds

  ## Returns
    - true if enough time has passed, false otherwise
  """
  @spec can_attack?(integer(), integer()) :: boolean()
  def can_attack?(last_attack_timestamp, attack_delay) do
    if last_attack_timestamp == 0 do
      true
    else
      current_time = System.monotonic_time(:millisecond)
      current_time >= last_attack_timestamp + attack_delay
    end
  end

  @doc """
  Gets the current monotonic timestamp in milliseconds.

  ## Returns
    - Current timestamp in milliseconds
  """
  @spec current_timestamp() :: integer()
  def current_timestamp do
    System.monotonic_time(:millisecond)
  end
end
