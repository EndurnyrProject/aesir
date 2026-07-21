defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Combo do
  @moduledoc """
  Pure, session-owned state for the ordinary Monk combo chain.

  Generations make delayed timeout messages harmless after a window advances or
  is cancelled. Deadlines use monotonic milliseconds supplied by the caller.
  """

  use TypedStruct

  @type stage :: :idle | :quadruple | :thrust
  @type target :: {:player | :mob | :skill_unit, non_neg_integer()}

  typedstruct do
    field :stage, stage(), default: :idle
    field :target, target()
    field :deadline, integer()
    field :generation, non_neg_integer(), default: 0
  end

  @doc "Returns an idle combo state."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Opens or replaces a combo window."
  @spec open(t(), stage(), target(), integer()) :: t()
  def open(%__MODULE__{} = combo, stage, target, deadline) when stage != :idle do
    %__MODULE__{
      stage: stage,
      target: target,
      deadline: deadline,
      generation: combo.generation + 1
    }
  end

  @doc "Advances a current window for the retained target."
  @spec advance(t(), stage(), stage(), target(), integer(), integer()) ::
          {:ok, t()} | {:error, :invalid_combo}
  def advance(combo, expected, next, target, deadline, now) do
    if current?(combo, expected, target, now) do
      {:ok, open(combo, next, target, deadline)}
    else
      {:error, :invalid_combo}
    end
  end

  @doc "Whether the given stage and target own a still-open window."
  @spec current?(t(), stage(), target(), integer()) :: boolean()
  def current?(%__MODULE__{} = combo, stage, target, now) do
    combo.stage == stage and combo.target == target and is_integer(combo.deadline) and
      now < combo.deadline
  end

  @doc "Expires a matching generation once its deadline has elapsed."
  @spec expire(t(), non_neg_integer(), integer()) :: t()
  def expire(%__MODULE__{} = combo, generation, now) do
    if combo.stage != :idle and combo.generation == generation and now >= combo.deadline,
      do: cancel(combo),
      else: combo
  end

  @doc "Cancels an active window and invalidates its outstanding timeout."
  @spec cancel(t()) :: t()
  def cancel(%__MODULE__{stage: :idle} = combo), do: combo

  def cancel(%__MODULE__{} = combo) do
    %__MODULE__{generation: combo.generation + 1}
  end
end
