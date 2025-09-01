defmodule Aesir.ZoneServer.Mmo.StatusEntry do
  @moduledoc """
  Struct for representing a status effect entry.

  Status effects in Ragnarok Online have specific parameters that determine their behavior:
  - val1-val4: Context-dependent values with different meanings per status type
  - tick: How often the status effect should be processed (in milliseconds)
  - flag: Special flags for status behavior
  - source_id: Who/what applied the status
  - state: Custom state data for complex statuses
  - phase: Current phase of multi-phase status effects
  """

  @typedoc """
  Parameters for applying a status effect.

  - `val1-val4`: Context-dependent values with different meanings per status type
  - `tick`: How often the status effect should be processed (in milliseconds, defaults to 0)
  - `flag`: Special flags for status behavior (defaults to 0)
  - `caster_id`: ID of the entity that applied the status (defaults to nil)
  - `duration`: How long the status lasts in milliseconds (defaults to nil for permanent)
  - `source_id`: Alias for caster_id for backward compatibility (defaults to nil)
  - `state`: Custom state data for complex statuses (defaults to empty map)
  - `phase`: Current phase for multi-phase status effects (defaults to nil)
  """
  @type status_params :: [
          val1: integer(),
          val2: integer(),
          val3: integer(),
          val4: integer(),
          tick: integer(),
          flag: integer(),
          caster_id: integer() | nil,
          duration: integer() | nil,
          source_id: integer() | nil,
          state: map(),
          phase: atom() | nil
        ]

  @type t :: %__MODULE__{
          type: atom(),
          val1: integer(),
          val2: integer(),
          val3: integer(),
          val4: integer(),
          tick: integer(),
          flag: integer(),
          source_id: integer(),
          state: map(),
          phase: atom() | nil,
          started_at: integer(),
          expires_at: integer() | nil,
          next_tick_at: integer(),
          tick_count: non_neg_integer()
        }

  defstruct [
    # The status effect type (e.g. :poison, :blessing)
    :type,
    # Value 1 (usage depends on status type)
    :val1,
    # Value 2 (usage depends on status type)
    :val2,
    # Value 3 (usage depends on status type)
    :val3,
    # Value 4 (usage depends on status type)
    :val4,
    # Tick interval in milliseconds
    :tick,
    # Status flags for special behaviors
    :flag,
    # ID of the entity that applied the status
    :source_id,
    # Custom state map for complex statuses
    :state,
    # Current phase for multi-phase statuses
    :phase,
    # System time when status was applied
    :started_at,
    # When the status expires (or nil if permanent)
    :expires_at,
    # When the next tick should process
    :next_tick_at,
    # Number of ticks processed so far
    :tick_count
  ]

  @doc """
  Creates a new status entry with the given parameters.
  """
  @spec new(
          atom(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer(),
          integer() | nil,
          integer() | nil,
          map() | nil,
          atom() | nil
        ) :: t()
  # credo:disable-for-next-line Credo.Check.Refactor.FunctionArity
  def new(
        type,
        val1,
        val2,
        val3,
        val4,
        tick,
        flag,
        duration \\ nil,
        source_id \\ nil,
        state \\ %{},
        phase \\ nil
      ) do
    now_ms = System.monotonic_time(:millisecond)
    tick_interval = if tick > 0, do: tick, else: 1000

    expires_at =
      if duration && duration > 0 do
        now_ms + duration
      else
        nil
      end

    %__MODULE__{
      type: type,
      val1: val1,
      val2: val2,
      val3: val3,
      val4: val4,
      tick: tick,
      flag: flag,
      source_id: source_id,
      state: state || %{},
      phase: phase,
      started_at: System.system_time(:millisecond),
      expires_at: expires_at,
      next_tick_at: now_ms + tick_interval,
      tick_count: 0
    }
  end

  @doc """
  Creates a new status entry from a map.
  """
  @spec from_map(map()) :: t()
  def from_map(map) do
    struct(__MODULE__, map)
  end

  @doc """
  Updates the next_tick_at field based on the current time.
  """
  @spec schedule_next_tick(t(), integer()) :: t()
  def schedule_next_tick(%__MODULE__{} = entry, now_ms) do
    tick_interval = if entry.tick > 0, do: entry.tick, else: 1000
    %{entry | next_tick_at: now_ms + tick_interval}
  end

  @doc """
  Increments the tick count for the status entry.
  """
  @spec increment_tick_count(t()) :: t()
  def increment_tick_count(%__MODULE__{} = entry) do
    %{entry | tick_count: entry.tick_count + 1}
  end

  @doc """
  Checks if a status has expired.
  """
  @spec expired?(t(), integer()) :: boolean()
  def expired?(%__MODULE__{expires_at: nil}, _now_ms), do: false
  def expired?(%__MODULE__{expires_at: expires_at}, now_ms), do: expires_at <= now_ms

  @doc """
  Checks if a status is due for a tick update.
  """
  @spec tick_due?(t(), integer()) :: boolean()
  def tick_due?(%__MODULE__{next_tick_at: next_tick_at}, now_ms), do: next_tick_at <= now_ms

  @doc """
  Extracts status parameters from a keyword list with defaults.

  This is a helper function for the refactored apply_status functions
  to convert keyword lists to individual parameter values.
  """
  @spec extract_params(status_params()) :: {
          val1 :: integer(),
          val2 :: integer(),
          val3 :: integer(),
          val4 :: integer(),
          tick :: integer(),
          flag :: integer(),
          caster_id :: integer() | nil,
          duration :: integer() | nil,
          state :: map(),
          phase :: atom() | nil
        }
  def extract_params(status_params \\ []) do
    defaults = [
      val1: 0,
      val2: 0,
      val3: 0,
      val4: 0,
      tick: 0,
      flag: 0,
      caster_id: nil,
      duration: nil,
      state: %{},
      phase: nil
    ]

    params = Keyword.merge(defaults, status_params)

    # Handle source_id as alias for caster_id for backward compatibility
    caster_id = params[:caster_id] || params[:source_id]

    {
      params[:val1],
      params[:val2],
      params[:val3],
      params[:val4],
      params[:tick],
      params[:flag],
      caster_id,
      params[:duration],
      params[:state],
      params[:phase]
    }
  end
end
