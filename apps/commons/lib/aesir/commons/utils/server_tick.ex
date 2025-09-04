defmodule Aesir.Commons.Utils.ServerTick do
  @moduledoc """
  Utility module for handling server tick timestamps consistently across the system.

  The Ragnarok Online client expects server timestamps as 32-bit values, so this module
  provides utilities to generate and work with truncated timestamps that fit within
  the client's expectations.

  ## Examples

      iex> tick = ServerTick.now()
      iex> is_integer(tick)
      true
      iex> tick > 0
      true
      iex> tick <= 0xFFFFFFFF
      true

  """

  @typedoc """
  A 32-bit server tick timestamp value suitable for network packets.
  """
  @type t :: 0..0xFFFFFFFF

  @doc """
  Gets the current server tick as a 32-bit timestamp.

  Returns the current system time in milliseconds, truncated to fit within
  a 32-bit unsigned integer as expected by the Ragnarok Online client.

  ## Returns
  32-bit timestamp value (0 to 4,294,967,295)

  ## Examples

      iex> tick = ServerTick.now()
      iex> is_integer(tick) and tick >= 0 and tick <= 0xFFFFFFFF
      true

  """
  @spec now() :: t()
  def now do
    System.system_time(:millisecond) |> rem(0x100000000)
  end

  @doc """
  Converts a full system timestamp to a 32-bit server tick.

  Takes a full system timestamp (typically from System.system_time/1) and
  truncates it to a 32-bit value suitable for network packets.

  ## Parameters
  - timestamp: Full system timestamp in milliseconds

  ## Returns
  32-bit timestamp value

  ## Examples

      iex> full_time = System.system_time(:millisecond)
      iex> tick = ServerTick.from_timestamp(full_time)
      iex> is_integer(tick) and tick >= 0 and tick <= 0xFFFFFFFF
      true

  """
  @spec from_timestamp(integer()) :: t()
  def from_timestamp(timestamp) when is_integer(timestamp) do
    timestamp |> rem(0x100000000)
  end

  @doc """
  Calculates the difference between two server ticks, handling 32-bit wraparound.

  Since server ticks are 32-bit values that can wrap around, this function
  correctly calculates the time difference accounting for potential wraparound.

  ## Parameters
  - tick1: First server tick
  - tick2: Second server tick

  ## Returns
  Signed difference in milliseconds (tick2 - tick1)

  ## Examples

      iex> tick1 = ServerTick.now()
      iex> Process.sleep(10)
      iex> tick2 = ServerTick.now()
      iex> diff = ServerTick.diff(tick1, tick2)
      iex> diff >= 0 and diff < 1000
      true

  """
  @spec diff(t(), t()) :: integer()
  def diff(tick1, tick2) when is_integer(tick1) and is_integer(tick2) do
    raw_diff = tick2 - tick1

    # Handle 32-bit wraparound
    cond do
      # Normal case - no wraparound
      raw_diff >= -0x80000000 and raw_diff <= 0x7FFFFFFF ->
        raw_diff

      # tick2 wrapped around, tick1 didn't
      raw_diff < -0x80000000 ->
        raw_diff + 0x100000000

      # tick1 wrapped around, tick2 didn't
      raw_diff > 0x7FFFFFFF ->
        raw_diff - 0x100000000
    end
  end

  @doc """
  Checks if a server tick value is valid.

  Validates that the given value is within the valid range for 32-bit server ticks.

  ## Parameters
  - tick: Value to validate

  ## Returns
  Boolean indicating if the tick is valid

  ## Examples

      iex> ServerTick.valid?(1000)
      true
      iex> ServerTick.valid?(-1)
      false
      iex> ServerTick.valid?(0x100000000)
      false

  """
  @spec valid?(any()) :: boolean()
  def valid?(tick) when is_integer(tick) and tick >= 0 and tick <= 0xFFFFFFFF, do: true
  def valid?(_), do: false

  @doc """
  Adds milliseconds to a server tick, handling wraparound.

  ## Parameters
  - tick: Starting server tick
  - milliseconds: Milliseconds to add (can be negative)

  ## Returns
  New server tick with wraparound handling

  ## Examples

      iex> tick = 1000
      iex> new_tick = ServerTick.add(tick, 500)
      iex> new_tick
      1500

  """
  @spec add(t(), integer()) :: t()
  def add(tick, milliseconds) when is_integer(tick) and is_integer(milliseconds) do
    (tick + milliseconds) |> rem(0x100000000) |> abs()
  end

  @doc """
  Checks if enough time has elapsed since a given tick.

  Useful for cooldown and timing checks in game logic.

  ## Parameters
  - start_tick: Starting server tick
  - duration_ms: Duration to check in milliseconds
  - current_tick: Current server tick (defaults to now())

  ## Returns
  Boolean indicating if the duration has elapsed

  ## Examples

      iex> start = ServerTick.now()
      iex> ServerTick.elapsed?(start, 0)
      true

  """
  @spec elapsed?(t(), non_neg_integer(), t()) :: boolean()
  def elapsed?(start_tick, duration_ms, current_tick \\ now())
      when is_integer(start_tick) and is_integer(duration_ms) and is_integer(current_tick) do
    diff(start_tick, current_tick) >= duration_ms
  end
end
