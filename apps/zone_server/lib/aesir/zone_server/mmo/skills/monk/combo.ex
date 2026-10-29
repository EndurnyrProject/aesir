defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Combo do
  @moduledoc """
  Session-owned state for the Monk and Champion combo chain. Everything is pure
  except `open_follow_up/7`, which reads the caster's Fury and schedules the
  window's timeout in the calling session.

  Generations make delayed timeout messages harmless after a window advances or
  is cancelled. Deadlines use monotonic milliseconds supplied by the caller.

  A window is not tied to a unit and holds no target: it only names the skill
  the chain allows next. A follow-up is aimed at the caster's current attack
  target when it starts (see `SkillHandler`).

  A window ends at its deadline, when its owner dies (its statuses go with it),
  and when its owner's other skill attack lands: `end_on_attack/2` applies that
  last rule to the window a skill effect returned, keeping a window that effect
  opened itself.

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
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Root
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @asura 271
  @chain_combo 272
  @thrust 273
  @grace_ms 300
  @tiger_fist 371
  @chain_crush 372
  @combo_skills [@asura, @chain_combo, @thrust, @tiger_fist, @chain_crush]
  @self_aimed [@chain_combo, @thrust, @tiger_fist, @chain_crush]

  @type stage :: :idle | :quadruple | :thrust | :extremity | :tiger_fist | :chain_crush
  @type follow_up_ctx :: %{
          learned: map(),
          spheres: non_neg_integer(),
          fury?: boolean()
        }
  defstruct stage: :idle, deadline: nil, generation: 0

  @type t() :: %__MODULE__{
          stage: stage(),
          deadline: integer() | nil,
          generation: non_neg_integer()
        }

  @doc """
  The target a combo skill's use is aimed at, given the target the player
  named and the unit they are attacking (`nil` when none).

  While a window is open and the skill's cast-begin conditions pass
  (`castbegin_ok`, evaluated only then), the use is aimed at the attack target;
  without one, a use aimed at the player themselves has no target. A
  self-aimed follow-up outside a window is aimed the same way. Raging
  Quadruple Blow under Root is then aimed at the caught unit. Any other skill
  keeps its target. `{:unit, 0}` names no unit.
  """
  @spec use_target(map(), integer(), term(), integer() | nil, (-> boolean())) :: term()
  def use_target(caster, skill_id, target, attack_target, castbegin_ok),
    do: caster |> aim(skill_id, target, attack_target, castbegin_ok) |> elem(0)

  @doc """
  `use_target/5`, plus whether the use counts as a combo: aimed by its window
  or as a self-aimed follow-up. A combo used while its caster is swinging at
  its attack target has the attack's reach and skips the skill's range check.
  """
  @spec aim(map(), integer(), term(), integer() | nil, (-> boolean())) :: {term(), boolean()}
  def aim(%{combo: combo} = caster, skill_id, target, attack_target, castbegin_ok)
      when skill_id in @combo_skills do
    now = System.monotonic_time(:millisecond)

    {target, combo?} =
      cond do
        open?(combo, now) and castbegin_ok.() ->
          {attack_target(target, attack_target), true}

        skill_id in @self_aimed and target == :self ->
          {attack_target(target, attack_target), true}

        true ->
          {target, false}
      end

    {root_target(caster, skill_id, target), combo?}
  end

  def aim(_caster, _skill_id, target, _attack_target, _castbegin_ok), do: {target, false}

  defp attack_target(_target, attack_target) when is_integer(attack_target) and attack_target > 0,
    do: {:unit, attack_target}

  defp attack_target(:self, _attack_target), do: {:unit, 0}
  defp attack_target(target, _attack_target), do: target

  defp root_target(%{character_id: caster_id}, @chain_combo, target) do
    case Root.linked_peer(:player, caster_id) do
      {_type, peer_id} -> {:unit, peer_id}
      nil -> target
    end
  end

  defp root_target(_caster, _skill_id, target), do: target

  @doc "Returns an idle combo state."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Opens or replaces a combo window."
  @spec open(t(), stage(), integer()) :: t()
  def open(%__MODULE__{} = combo, stage, deadline) when stage != :idle do
    %__MODULE__{stage: stage, deadline: deadline, generation: combo.generation + 1}
  end

  @doc "Whether a window is open at `now` (any stage)."
  @spec open?(t(), integer()) :: boolean()
  def open?(%__MODULE__{stage: stage, deadline: deadline}, now),
    do: stage != :idle and is_integer(deadline) and deadline != 0 and now < deadline

  @doc "Whether the open window is one of `stages` at `now`."
  @spec open?(t(), stage() | [stage()], integer()) :: boolean()
  def open?(%__MODULE__{} = combo, stages, now) when is_list(stages),
    do: open?(combo, now) and combo.stage in stages

  def open?(combo, stage, now), do: open?(combo, [stage], now)

  @doc """
  The cast-begin condition of a combo follow-up: the window must be one of
  `stages`, or the skill is refused silently.
  """
  @spec check(t(), stage() | [stage()], integer()) :: :ok | {:error, :invalid_combo}
  def check(combo, stages, now),
    do: if(open?(combo, stages, now), do: :ok, else: {:error, :invalid_combo})

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
  Opens the window a landed `opener` earns, replacing any open one, or closes
  the chain. `caster` has already paid the opener's spheres. The window lasts
  `delay` plus the grace and schedules `{:combo_timeout, generation}` to the
  calling session.
  """
  @spec open_follow_up(
          map(),
          :quadruple | :thrust | :tiger_fist | :chain_crush,
          integer(),
          non_neg_integer()
        ) :: {:ok, t()}
  def open_follow_up(caster, opener, now, delay) do
    ctx = %{
      learned: PlayerStats.effective_skills(caster.stats),
      spheres: SpiritSpheres.count(caster.spirit_spheres),
      fury?: Fury.active?(caster.character_id)
    }

    case follow_up_stage(opener, ctx) do
      :idle ->
        {:ok, cancel(caster.combo)}

      stage ->
        window = delay + @grace_ms

        combo = open(caster.combo, stage, now + window)
        Process.send_after(self(), {:combo_timeout, combo.generation}, window)
        {:ok, combo}
    end
  end

  @doc """
  The window a Raging Trifecta Blow proc at `now` earns, after the proc armed
  its skill delay: while the caster knows Raging Quadruple Blow it lasts until
  the caster may use skills again, at least the caster's `amotion`, plus the
  grace, and schedules `{:combo_timeout, generation}` to the calling session.
  Otherwise any open window ends.
  """
  @spec open_after_trifecta(map(), integer(), non_neg_integer()) :: t()
  def open_after_trifecta(caster, now, amotion) do
    if knows?(%{learned: PlayerStats.effective_skills(caster.stats)}, @chain_combo) do
      window = max(amotion, caster.act_delay_until - now) + @grace_ms
      combo = open(caster.combo, :quadruple, now + window)
      Process.send_after(self(), {:combo_timeout, combo.generation}, window)
      combo
    else
      cancel(caster.combo)
    end
  end

  defp asura?(ctx, min_spheres),
    do: knows?(ctx, @asura) and ctx.fury? and ctx.spheres >= min_spheres

  defp knows?(%{learned: learned}, skill_id), do: Learned.learned_level(learned, skill_id) > 0

  defp pre_renewal?, do: GameMode.mode() == :pre_renewal

  @doc """
  Ends a window the window's owner ended by another skill attack.

  `before` is the caster's combo state when its skill effect started and
  `after_effect` the one that effect returned. The reference ends `SC_COMBO`
  inside every skill attack its owner makes and then opens the window that
  attack earns, so a window the effect left untouched is ended here and one the
  effect opened or closed itself is kept.
  """
  @spec end_on_attack(t(), t()) :: t()
  def end_on_attack(%__MODULE__{} = before, %__MODULE__{} = after_effect) do
    if after_effect.generation == before.generation,
      do: cancel(after_effect),
      else: after_effect
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
