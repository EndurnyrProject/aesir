defmodule Aesir.ZoneServer.Unit.Player.NaturalHeal do
  @moduledoc """
  Pure core of a player's natural regeneration, run once per 500 ms session tick.

  It works in two steps:

  - `plan/1` turns the facts the session gathered (`Inputs`) into the amounts,
    interval rates and channel flags of one tick (`Plan`).
  - `tick/4` runs one tick of the loop over the per-session `Timing` and the
    current vitals, returning the HP and SP to restore.

  ## Channels

  - **Natural HP/SP**: `vit / 5 + max(1, max_hp / 200)` HP every 6000 ms and
    `1 + int / 6 + max_sp / 100` SP (plus `(int - 120) / 2 + 4` from INT 120)
    every 8000 ms, from effective VIT/INT, scaled by the recovery amount rates
    (`hp_regen`/`sp_regen`), SP then by Meditatio. Each interval is divided by
    the tick rate (`100` plus `hp_regen_tick_rate`/`sp_regen_tick_rate`) and by
    a multiplier that grows by one while sitting and by one on an owned guild
    castle map; the HP interval doubles while walking and the SP interval is
    multiplied by `natural_sp_interval_multiplier`. 250 ms of timer slack is
    taken off. A channel heals at most once per tick, when its last heal is at
    least one interval old, and restarts its interval whenever it is off.
  - **Skill HP/SP** (HP Recovery, SP Recovery): flat amounts every 10 000 ms of
    accumulated time, the HP accumulator scaled by the skill tick rate. They
    pause (keeping their progress) while walking or at full HP/SP.
  - **Sitting skill HP/SP** (Spiritual Cadence): flat amounts every 10 000 ms
    of accumulated sitting time, half as fast while overweight. They run before
    the overweight and walking gates.

  ## Blocks

  `no_regen` (Poison, Bleeding, Berserk, ...) stops every channel;
  `no_natural_hp_regen`/`no_natural_sp_regen` stop one natural channel; the
  equipment no-regen mask stops the natural and skill channels of HP (bit 1)
  and SP (bit 2). Death and concealment stop everything, and overweight stops
  everything but sitting regen. Tension Relax while overweight lifts the
  overweight block instead of raising the HP tick rates.

  It performs no process work and never reads the clock: the session advances
  `Timing.clock_ms` by the elapsed time it passes in.
  """

  alias Aesir.ZoneServer.Unit.Player.Stats

  @hp_interval 6_000
  @sp_interval 8_000
  @skill_interval 10_000
  @timer_slack 250
  @amount_cap 32_767

  defmodule Inputs do
    @moduledoc """
    The facts one regeneration tick reads from the player and its session.

    `modifiers` is the merged status modifier map with the equipment recovery
    rates folded into `hp_regen`/`sp_regen`. `no_regen_mask` is the equipment
    no-regen bitmask (1 HP, 2 SP). `blocked?` is dead or concealed.
    """
    alias Aesir.ZoneServer.Mmo.Skill.Passives
    alias Aesir.ZoneServer.Unit.Player.Stats

    @enforce_keys [
      :stats,
      :modifiers,
      :passive_regen,
      :sitting_regen,
      :no_regen_mask,
      :sitting?,
      :walking?,
      :overweight?,
      :castle_bonus?,
      :blocked?,
      :tension_relax?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            stats: Stats.t(),
            modifiers: map(),
            passive_regen: Passives.regen(),
            sitting_regen: Passives.sitting_regen(),
            no_regen_mask: 0..3,
            sitting?: boolean(),
            walking?: boolean(),
            overweight?: boolean(),
            castle_bonus?: boolean(),
            blocked?: boolean(),
            tension_relax?: boolean()
          }
  end

  defmodule Plan do
    @moduledoc """
    One tick's amounts, interval rates (percent, 100 is base) and channel flags.
    """
    @enforce_keys [
      :hp,
      :sp,
      :skill_hp,
      :skill_sp,
      :sitting_hp,
      :sitting_sp,
      :hp_rate,
      :sp_rate,
      :skill_hp_rate,
      :sp_interval_multiplier,
      :natural_hp?,
      :natural_sp?,
      :skill_hp?,
      :skill_sp?,
      :sitting?,
      :walking?,
      :walk_regen?,
      :overweight?,
      :castle_bonus?,
      :blocked?
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            hp: non_neg_integer(),
            sp: non_neg_integer(),
            skill_hp: non_neg_integer(),
            skill_sp: non_neg_integer(),
            sitting_hp: non_neg_integer(),
            sitting_sp: non_neg_integer(),
            hp_rate: pos_integer(),
            sp_rate: pos_integer(),
            skill_hp_rate: pos_integer(),
            sp_interval_multiplier: pos_integer(),
            natural_hp?: boolean(),
            natural_sp?: boolean(),
            skill_hp?: boolean(),
            skill_sp?: boolean(),
            sitting?: boolean(),
            walking?: boolean(),
            walk_regen?: boolean(),
            overweight?: boolean(),
            castle_bonus?: boolean(),
            blocked?: boolean()
          }
  end

  defmodule Timing do
    @moduledoc """
    Per-session regeneration timing: the session clock, the clock of the last
    natural HP and SP heal (`nil` before the first, which makes it due), and the
    millisecond accumulators of the skill and sitting skill channels.
    """
    defstruct clock_ms: 0,
              hp_last_ms: nil,
              sp_last_ms: nil,
              skill_hp_acc: 0,
              skill_sp_acc: 0,
              sitting_hp_acc: 0,
              sitting_sp_acc: 0

    @type t :: %__MODULE__{
            clock_ms: non_neg_integer(),
            hp_last_ms: non_neg_integer() | nil,
            sp_last_ms: non_neg_integer() | nil,
            skill_hp_acc: non_neg_integer(),
            skill_sp_acc: non_neg_integer(),
            sitting_hp_acc: non_neg_integer(),
            sitting_sp_acc: non_neg_integer()
          }

    @doc "Timing at session start and after death: every natural heal due, no progress."
    @spec initial() :: t()
    def initial, do: %__MODULE__{}
  end

  @typedoc """
  Current and maximum HP/SP the tick heals against. `gate_hp`/`gate_sp` (default
  `hp`/`sp`) are the values the skill channels' full gate reads: HP and SP
  before this tick's equipment regeneration and loss.
  """
  @type vitals :: %{
          required(:hp) => integer(),
          required(:sp) => integer(),
          required(:max_hp) => integer(),
          required(:max_sp) => integer(),
          optional(:gate_hp) => integer(),
          optional(:gate_sp) => integer()
        }

  @doc """
  Computes one tick's amounts, rates and channel flags from the gathered facts.
  """
  @spec plan(Inputs.t()) :: Plan.t()
  def plan(%Inputs{stats: stats, modifiers: modifiers} = inputs) do
    relaxed? = inputs.tension_relax? and inputs.overweight?

    amounts = %{
      hp: natural_hp(stats, Map.get(modifiers, :hp_regen, 0)),
      sp: natural_sp(stats, Map.get(modifiers, :sp_regen, 0)),
      skill_hp: cap(inputs.passive_regen.skill_hp_regen, 0),
      skill_sp: cap(inputs.passive_regen.skill_sp_regen, 0),
      sitting_hp: cap(inputs.sitting_regen.sitting_hp_regen, 0),
      sitting_sp: cap(inputs.sitting_regen.sitting_sp_regen, 0)
    }

    facts = %{
      sitting?: inputs.sitting?,
      walking?: inputs.walking?,
      walk_regen?: inputs.passive_regen.allow_while_moving,
      overweight?: inputs.overweight? and not relaxed?,
      castle_bonus?: inputs.castle_bonus?,
      blocked?: inputs.blocked?
    }

    struct!(
      Plan,
      amounts
      |> Map.merge(facts)
      |> Map.merge(rates(modifiers, relaxed?))
      |> Map.merge(channels(modifiers, inputs.no_regen_mask, amounts))
    )
  end

  # Tension Relax while overweight grants no HP tick rate (it lifts the
  # overweight block instead).
  defp rates(modifiers, relaxed?) do
    relax_offset = if relaxed?, do: 200, else: 0

    %{
      hp_rate: 100 + Map.get(modifiers, :hp_regen_tick_rate, 0) - relax_offset,
      sp_rate: 100 + Map.get(modifiers, :sp_regen_tick_rate, 0),
      skill_hp_rate: 100 + Map.get(modifiers, :skill_hp_regen_tick_rate, 0) - relax_offset,
      sp_interval_multiplier: max(Map.get(modifiers, :natural_sp_interval_multiplier, 1), 1)
    }
  end

  defp channels(modifiers, mask, amounts) do
    regen? = not Map.get(modifiers, :no_regen, false)
    hp? = regen? and Bitwise.band(mask, 1) == 0
    sp? = regen? and Bitwise.band(mask, 2) == 0

    %{
      natural_hp?: hp? and not Map.get(modifiers, :no_natural_hp_regen, false),
      natural_sp?: sp? and not Map.get(modifiers, :no_natural_sp_regen, false),
      skill_hp?: hp? and (amounts.skill_hp > 0 or amounts.sitting_hp > 0),
      skill_sp?: sp? and (amounts.skill_sp > 0 or amounts.sitting_sp > 0)
    }
  end

  @doc """
  Runs one tick of `elapsed` milliseconds.

  Returns `{hp_delta, sp_delta, timing}`; the deltas never take HP or SP past
  their maximums.
  """
  @spec tick(Plan.t(), Timing.t(), non_neg_integer(), vitals()) ::
          {non_neg_integer(), non_neg_integer(), Timing.t()}
  def tick(%Plan{} = plan, %Timing{} = timing, elapsed, %{hp: hp, sp: sp} = vitals) do
    clock = timing.clock_ms + elapsed

    flags = %{
      hp: plan.natural_hp?,
      sp: plan.natural_sp?,
      shp: plan.skill_hp? and Map.get(vitals, :gate_hp, hp) < vitals.max_hp,
      ssp: plan.skill_sp? and Map.get(vitals, :gate_sp, sp) < vitals.max_sp
    }

    flags = if plan.blocked?, do: all_off(), else: flags
    run = %{hp: hp, sp: sp, timing: timing, flags: flags}

    run =
      run
      |> sitting_regen(plan, elapsed, vitals)
      |> gate_overweight_and_walking(plan)
      |> natural(:hp, plan, clock, vitals)
      |> natural(:sp, plan, clock, vitals)
      |> skill_regen(:hp, plan, elapsed, vitals)
      |> skill_regen(:sp, plan, elapsed, vitals)

    {run.hp - hp, run.sp - sp, %{run.timing | clock_ms: clock}}
  end

  defp all_off, do: %{hp: false, sp: false, shp: false, ssp: false}

  defp sitting_regen(%{flags: flags} = run, %Plan{sitting?: true} = plan, elapsed, vitals) do
    gained = if plan.overweight?, do: div(elapsed, 2), else: elapsed

    run
    |> sitting_channel(:hp, flags.shp, plan.sitting_hp, gained, vitals.max_hp)
    |> sitting_channel(:sp, flags.ssp, plan.sitting_sp, gained, vitals.max_sp)
  end

  defp sitting_regen(run, _plan, _elapsed, _vitals), do: run

  defp sitting_channel(run, _resource, false, _amount, _gained, _max), do: run

  defp sitting_channel(run, resource, true, amount, gained, max) do
    key = sitting_acc(resource)
    acc = Map.fetch!(run.timing, key) + gained

    {value, acc, full?} = heal_loop(Map.fetch!(run, resource), acc, amount, max)
    flags = if full?, do: Map.put(run.flags, skill_flag(resource), false), else: run.flags

    %{run | timing: Map.put(run.timing, key, acc), flags: flags}
    |> Map.put(resource, value)
  end

  defp gate_overweight_and_walking(run, %Plan{overweight?: true}), do: %{run | flags: all_off()}

  defp gate_overweight_and_walking(%{flags: flags} = run, %Plan{walking?: true} = plan),
    do: %{run | flags: %{flags | shp: false, ssp: false, hp: flags.hp and plan.walk_regen?}}

  defp gate_overweight_and_walking(run, _plan), do: run

  defp natural(run, resource, plan, clock, vitals) do
    last_key = last_heal(resource)

    if Map.fetch!(run.flags, resource) do
      last = Map.fetch!(run.timing, last_key)

      if last == nil or last + natural_interval(resource, plan) <= clock do
        run = %{run | timing: Map.put(run.timing, last_key, clock)}
        natural_heal(run, resource, natural_amount(resource, plan), max_of(resource, vitals))
      else
        run
      end
    else
      %{run | timing: Map.put(run.timing, last_key, clock)}
    end
  end

  defp natural_heal(run, resource, amount, max) do
    current = Map.fetch!(run, resource)
    skill = skill_flag(resource)

    cond do
      current >= max ->
        %{run | flags: %{run.flags | resource => false, skill => false}}

      amount > max - current ->
        %{Map.put(run, resource, max) | flags: Map.put(run.flags, skill, false)}

      true ->
        Map.put(run, resource, current + amount)
    end
  end

  defp natural_interval(:hp, plan) do
    interval = div(@hp_interval * 100, plan.hp_rate * multiplier(plan))
    interval = if plan.walking?, do: interval * 2, else: interval
    interval - @timer_slack
  end

  defp natural_interval(:sp, plan) do
    div(@sp_interval * 100, plan.sp_rate * multiplier(plan)) * plan.sp_interval_multiplier -
      @timer_slack
  end

  defp multiplier(plan), do: 1 + bool(plan.sitting?) + bool(plan.castle_bonus?)

  defp bool(true), do: 1
  defp bool(false), do: 0

  defp skill_regen(run, resource, plan, elapsed, vitals) do
    if Map.fetch!(run.flags, skill_flag(resource)) do
      key = skill_acc(resource)
      acc = Map.fetch!(run.timing, key) + skill_gain(resource, plan, elapsed)
      amount = skill_amount(resource, plan)

      {value, acc, _full?} =
        heal_loop(Map.fetch!(run, resource), acc, amount, max_of(resource, vitals))

      %{run | timing: Map.put(run.timing, key, acc)} |> Map.put(resource, value)
    else
      run
    end
  end

  defp skill_gain(:hp, plan, elapsed), do: div(elapsed * plan.skill_hp_rate, 100)
  defp skill_gain(:sp, _plan, elapsed), do: elapsed

  # Heals `amount` per whole skill interval in `acc`, stopping (with the rest
  # of `acc` kept) as soon as a heal does not fit in full.
  defp heal_loop(value, acc, amount, max) when acc >= @skill_interval do
    acc = acc - @skill_interval
    healed = min(amount, max(max - value, 0))

    if healed < amount,
      do: {value + healed, acc, true},
      else: heal_loop(value + healed, acc, amount, max)
  end

  defp heal_loop(value, acc, _amount, _max), do: {value, acc, false}

  defp natural_amount(:hp, plan), do: plan.hp
  defp natural_amount(:sp, plan), do: plan.sp

  defp skill_amount(:hp, plan), do: plan.skill_hp
  defp skill_amount(:sp, plan), do: plan.skill_sp

  defp max_of(:hp, vitals), do: vitals.max_hp
  defp max_of(:sp, vitals), do: vitals.max_sp

  defp skill_flag(:hp), do: :shp
  defp skill_flag(:sp), do: :ssp

  defp last_heal(:hp), do: :hp_last_ms
  defp last_heal(:sp), do: :sp_last_ms

  defp skill_acc(:hp), do: :skill_hp_acc
  defp skill_acc(:sp), do: :skill_sp_acc

  defp sitting_acc(:hp), do: :sitting_hp_acc
  defp sitting_acc(:sp), do: :sitting_sp_acc

  defp natural_hp(%Stats{} = stats, recov) do
    vit = Stats.get_effective_stat(stats, :vit)
    amount = div(vit, 5) + max(1, div(stats.derived_stats.max_hp, 200))
    cap(div(amount * (100 + recov), 100), 0)
  end

  defp natural_sp(%Stats{} = stats, recov) do
    int = Stats.get_effective_stat(stats, :int)
    amount = 1 + div(int, 6) + div(stats.derived_stats.max_sp, 100)
    amount = if int >= 120, do: amount + div(int - 120, 2) + 4, else: amount
    amount = cap(div(amount * (100 + recov), 100), 0)

    case meditatio_rate(stats) do
      0 -> amount
      rate -> cap(div(amount * (100 + rate), 100), 1)
    end
  end

  defp meditatio_rate(%Stats{modifiers: modifiers}) do
    modifiers |> Map.get(:passive, %{}) |> Map.get(:sp_regen_rate, 0)
  end

  defp cap(value, floor), do: value |> max(floor) |> min(@amount_cap)
end
