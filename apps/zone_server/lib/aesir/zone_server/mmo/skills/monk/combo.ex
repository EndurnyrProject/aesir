defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Combo do
  @moduledoc """
  Session-owned state for the Monk and Champion combo chain. Everything is pure
  except `open_follow_up/7`, which reads the caster's Fury and schedules the
  window's timeout in the calling session.

  Generations make delayed timeout messages harmless after a window advances or
  is cancelled. Deadlines use monotonic milliseconds supplied by the caller.

  Stages: `:quadruple` and `:thrust` name the skill the window allows;
  `:extremity` is the window after Raging Thrust; `:tiger_fist` and
  `:chain_crush` are the windows after Glacier Fist and Chain Crush Combo.

  `follow_up_stage/2` decides which window a landed combo skill opens, from the
  skills the caster knows, the spirit spheres left after that skill's own cost,
  and whether Fury is active:

    * after Raging Quadruple Blow: Raging Thrust (1+ sphere);
    * after Raging Thrust: Glacier Fist (1+ sphere), Chain Crush (2+), or Asura
      Strike (4+ and Fury);
    * after Glacier Fist: Chain Crush (2+);
    * after Chain Crush: Asura Strike (1+ and Fury).

  Renewal and pre-renewal share these rules, except that in pre-renewal Chain
  Crush also opens toward Glacier Fist (1+ sphere), so the two can loop.

  A window a combo skill opens lasts its after-cast delay plus a 300 ms grace,
  so the follow-up can be cast once the delay has passed.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Fury
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres

  @asura 271
  @thrust 273
  @grace_ms 300
  @tiger_fist 371
  @chain_crush 372

  @type stage :: :idle | :quadruple | :thrust | :extremity | :tiger_fist | :chain_crush
  @type follow_up_ctx :: %{
          learned: map(),
          spheres: non_neg_integer(),
          fury?: boolean()
        }
  @type target :: {:player | :mob | :skill_unit, non_neg_integer()}

  defstruct stage: :idle, target: nil, deadline: nil, generation: 0

  @type t() :: %__MODULE__{
          stage: stage(),
          target: target() | nil,
          deadline: integer() | nil,
          generation: non_neg_integer()
        }

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

  @doc "Advances a current window (any of `expected`) for the retained target."
  @spec advance(t(), stage() | [stage()], stage(), target(), integer(), integer()) ::
          {:ok, t()} | {:error, :invalid_combo}
  def advance(combo, expected, next, target, deadline, now) do
    if current?(combo, expected, target, now) do
      {:ok, open(combo, next, target, deadline)}
    else
      {:error, :invalid_combo}
    end
  end

  @doc "Whether the given stage (or any of a list) and target own a still-open window."
  @spec current?(t(), stage() | [stage()], target(), integer()) :: boolean()
  def current?(%__MODULE__{} = combo, stages, target, now) when is_list(stages) do
    combo.stage in stages and combo.target == target and is_integer(combo.deadline) and
      now < combo.deadline
  end

  def current?(combo, stage, target, now), do: current?(combo, [stage], target, now)

  @doc "Validates a stage (or any of a list) and target id, returning the retained typed target."
  @spec validate(t(), stage() | [stage()], non_neg_integer() | target(), integer()) ::
          {:ok, target()} | {:error, :invalid_combo}
  def validate(%__MODULE__{} = combo, stage, {target_type, target_id}, now)
      when stage != :idle and target_type in [:player, :mob, :skill_unit] and
             is_integer(target_id) and is_integer(now) do
    if combo.deadline != 0 and current?(combo, stage, {target_type, target_id}, now),
      do: {:ok, {target_type, target_id}},
      else: {:error, :invalid_combo}
  end

  def validate(%__MODULE__{} = combo, stage, target_id, now)
      when stage != :idle and is_integer(target_id) and is_integer(now) do
    case combo.target do
      {_, ^target_id} = target ->
        if combo.deadline != 0 and current?(combo, stage, target, now),
          do: {:ok, target},
          else: {:error, :invalid_combo}

      _ ->
        {:error, :invalid_combo}
    end
  end

  def validate(_combo, _stage, _target_id, _now), do: {:error, :invalid_combo}

  @doc """
  Returns the window a landed combo skill opens, or `:idle` when the chain
  closes. `spheres` must be the count left after the skill's own cost.
  """
  @spec follow_up_stage(:quadruple | :thrust | :tiger_fist | :chain_crush, follow_up_ctx()) ::
          stage()
  def follow_up_stage(:quadruple, ctx) do
    if knows?(ctx, @thrust) and ctx.spheres >= 1, do: :thrust, else: :idle
  end

  def follow_up_stage(:thrust, ctx) do
    if (knows?(ctx, @tiger_fist) and ctx.spheres >= 1) or
         (knows?(ctx, @chain_crush) and ctx.spheres >= 2) or asura?(ctx, 4),
       do: :extremity,
       else: :idle
  end

  def follow_up_stage(:tiger_fist, ctx) do
    if knows?(ctx, @chain_crush) and ctx.spheres >= 2, do: :tiger_fist, else: :idle
  end

  def follow_up_stage(:chain_crush, ctx) do
    if asura?(ctx, 1) or (pre_renewal?() and knows?(ctx, @tiger_fist) and ctx.spheres >= 1),
      do: :chain_crush,
      else: :idle
  end

  @doc """
  Opens the window a landed `opener` earns, advancing from any `expected`
  stage on `target`, or closes the chain. `caster` has already paid the
  opener's spheres. The window lasts `delay` plus the grace and schedules
  `{:combo_timeout, generation}` to the calling session.
  """
  @spec open_follow_up(
          map(),
          :quadruple | :thrust | :tiger_fist | :chain_crush,
          stage() | [stage()],
          target(),
          integer(),
          non_neg_integer()
        ) :: {:ok, t()} | {:error, :invalid_combo}
  def open_follow_up(caster, opener, expected, target, now, delay) do
    ctx = %{
      learned: caster.stats.progression.learned_skills,
      spheres: SpiritSpheres.count(caster.spirit_spheres),
      fury?: Fury.active?(caster.character_id)
    }

    case follow_up_stage(opener, ctx) do
      :idle ->
        {:ok, cancel(caster.combo)}

      stage ->
        window = delay + @grace_ms

        with {:ok, combo} <- advance(caster.combo, expected, stage, target, now + window, now) do
          Process.send_after(self(), {:combo_timeout, combo.generation}, window)
          {:ok, combo}
        end
    end
  end

  defp asura?(ctx, min_spheres),
    do: knows?(ctx, @asura) and ctx.fury? and ctx.spheres >= min_spheres

  defp knows?(%{learned: learned}, skill_id), do: Learned.learned_level(learned, skill_id) > 0

  defp pre_renewal?, do: GameMode.mode() == :pre_renewal

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
