defmodule Aesir.ZoneServer.Unit.Player.NaturalHeal do
  @moduledoc """
  Pure rAthena renewal natural-healing calculation.

  Natural healing is an *interval + amount* model: a fixed HP/SP amount is
  restored every effective interval (in milliseconds). This module is the pure
  core of that mechanic — given the player's stats, action/movement state, the
  aggregated status regen modifiers, the passive regen contribution, and a
  carried `accumulators` map, it returns the HP/SP to restore this call plus the
  updated accumulators.

  It performs no process work and never reads the clock: elapsed time is supplied
  via `accumulators.elapsed_ms`, so the function is fully deterministic and
  testable without a session.

  ## Channels (rAthena renewal, `status.cpp` `status_calc_regen` /
  `status_natural_heal`)

  Four independent interval+amount channels, each with its own accumulator so
  sub-interval progress is never lost:

  1. **Base HP** — amount `vit / 5 + max(1, max_hp / 200)`, base interval 6000ms;
     sitting halves the interval (≈2× faster); moving disables it unless
     `passive_regen.allow_while_moving` (SM_MOVINGRECOVERY). Percent modifiers
     from status effects (`regen_modifiers[:hp_regen]`) apply; `rate <= 0` (e.g.
     bleeding `-100`) zeroes it.
  2. **Base SP** — amount `1 + int / 6 + max_sp / 100` (+ `(int - 120) / 2 + 4`
     when `int >= 120`), base interval 8000ms; sitting halves; **not** disabled by
     moving. Percent modifiers (`regen_modifiers[:sp_regen]`) apply.
  3. **Skill HP regen** (rAthena `sregen`, `status.cpp:15618`) — flat amount
     `passive_regen.skill_hp_regen` (SM_RECOVERY), interval 10000ms
     (`natural_heal_skill_interval`). Gated like base HP: fires while **not moving**
     (standing-idle *or* sitting), disabled while moving unless
     `allow_while_moving`. Sitting does **not** speed it up; the separate
     `ssregen` channel handles MO_SPIRITSRECOVERY/TK recovery below.
     `skill_sp_regen` (MG_SRECOVERY) feeds the analogous skill SP channel.
  4. **Sitting skill HP/SP regen** — flat amounts from Spiritual Cadence,
     interval 10000ms. This separate channel advances only while sitting and
     preserves paused progress otherwise; it does not use status recovery modifiers.

  (all integer division). The skill HP regen folds into `hp_delta`; the combined
  HP delta is clamped so HP never exceeds `max_hp`.

  ## Accumulators

  `accumulators` carries the elapsed time for the current call and the fractional
  millisecond progress toward the next heal for each channel between calls:

      %{elapsed_ms: non_neg_integer(),
        hp_acc: non_neg_integer(), sp_acc: non_neg_integer(),
        skill_hp_acc: non_neg_integer(), skill_sp_acc: non_neg_integer(),
        optional(:sitting_hp_acc) => non_neg_integer(),
        optional(:sitting_sp_acc) => non_neg_integer()}

  The caller sets `:elapsed_ms` (time since the previous tick); the function folds
  it into each channel's accumulator, emits one amount per whole interval crossed,
  and returns the leftover sub-interval progress so it is not lost.
  """

  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @hp_interval 6_000
  @sp_interval 8_000
  @skill_interval 10_000

  @typedoc "Carried timing/fractional state between successive ticks."
  @type accumulators :: %{
          elapsed_ms: non_neg_integer(),
          hp_acc: non_neg_integer(),
          sp_acc: non_neg_integer(),
          skill_hp_acc: non_neg_integer(),
          skill_sp_acc: non_neg_integer()
        }

  @typedoc "Aggregated status regen modifiers (percent units, e.g. -100)."
  @type regen_modifiers :: %{
          optional(:hp_regen) => integer(),
          optional(:sp_regen) => integer(),
          optional(:regen_interval_multiplier) => pos_integer()
        }

  @typedoc "Passive regen contribution (flat skill-regen amounts + moving flag)."
  @type passive_regen :: %{
          skill_hp_regen: integer(),
          skill_sp_regen: integer(),
          allow_while_moving: boolean()
        }

  @typedoc "Sitting-only passive recovery amounts."
  @type sitting_regen :: %{sitting_hp_regen: integer(), sitting_sp_regen: integer()}

  @doc """
  Computes the HP/SP to restore this tick and the updated accumulators.

  Returns `{hp_delta, sp_delta, accumulators}`; both deltas are non-negative and
  clamped so current HP/SP can never exceed their maximums.
  """
  @spec compute(
          PlayerStats.t(),
          atom(),
          atom(),
          regen_modifiers(),
          passive_regen(),
          accumulators()
        ) :: {non_neg_integer(), non_neg_integer(), accumulators()}
  def compute(
        %PlayerStats{} = stats,
        action_state,
        movement_state,
        regen_modifiers,
        passive_regen,
        accumulators
      ),
      do:
        compute(
          stats,
          action_state,
          movement_state,
          regen_modifiers,
          passive_regen,
          %{sitting_hp_regen: 0, sitting_sp_regen: 0},
          accumulators
        )

  @doc """
  Computes natural healing with a separate sitting-only passive contribution.
  """
  @spec compute(
          PlayerStats.t(),
          atom(),
          atom(),
          regen_modifiers(),
          passive_regen(),
          sitting_regen(),
          accumulators()
        ) :: {non_neg_integer(), non_neg_integer(), accumulators()}
  def compute(
        %PlayerStats{} = stats,
        action_state,
        movement_state,
        regen_modifiers,
        passive_regen,
        sitting_regen,
        accumulators
      ) do
    elapsed = Map.get(accumulators, :elapsed_ms, 0)
    sitting? = action_state == :sitting
    moving? = movement_state == :moving
    interval_multiplier = interval_multiplier(regen_modifiers)

    hp_room = stats.derived_stats.max_hp - stats.current_state.hp
    sp_room = stats.derived_stats.max_sp - stats.current_state.sp

    base_hp_allowed? = hp_room > 0 and (not moving? or passive_regen.allow_while_moving)
    base_sp_allowed? = sp_room > 0
    skill_hp_allowed? = base_hp_allowed?
    skill_sp_allowed? = sp_room > 0

    {base_hp_raw, hp_acc} =
      channel(
        base_hp_allowed?,
        regen_hp(stats),
        rate(regen_modifiers, :hp_regen),
        @hp_interval,
        sitting?,
        Map.get(accumulators, :hp_acc, 0),
        elapsed,
        interval_multiplier
      )

    {skill_hp_raw, skill_hp_acc} =
      channel(
        skill_hp_allowed?,
        passive_regen.skill_hp_regen,
        100,
        @skill_interval,
        false,
        Map.get(accumulators, :skill_hp_acc, 0),
        elapsed,
        interval_multiplier
      )

    {base_sp_raw, sp_acc} =
      channel(
        base_sp_allowed?,
        regen_sp(stats),
        rate(regen_modifiers, :sp_regen),
        @sp_interval,
        sitting?,
        Map.get(accumulators, :sp_acc, 0),
        elapsed,
        interval_multiplier
      )

    {skill_sp_raw, skill_sp_acc} =
      channel(
        skill_sp_allowed?,
        passive_regen.skill_sp_regen,
        100,
        @skill_interval,
        false,
        Map.get(accumulators, :skill_sp_acc, 0),
        elapsed,
        interval_multiplier
      )

    {sitting_hp_raw, sitting_sp_raw, sitting_accumulators} =
      sitting_regen(
        sitting? and not moving?,
        hp_room,
        sp_room,
        sitting_regen,
        accumulators,
        elapsed,
        interval_multiplier
      )

    hp_delta = min(base_hp_raw + skill_hp_raw + sitting_hp_raw, hp_room)
    sp_delta = min(base_sp_raw + skill_sp_raw + sitting_sp_raw, sp_room)

    updated_accumulators =
      %{
        elapsed_ms: 0,
        hp_acc: hp_acc,
        sp_acc: sp_acc,
        skill_hp_acc: skill_hp_acc,
        skill_sp_acc: skill_sp_acc
      }
      |> Map.merge(sitting_accumulators)

    {hp_delta, sp_delta, updated_accumulators}
  end

  @spec sitting_regen(
          boolean(),
          integer(),
          integer(),
          sitting_regen(),
          accumulators(),
          non_neg_integer(),
          pos_integer()
        ) :: {non_neg_integer(), non_neg_integer(), map()}
  defp sitting_regen(
         false,
         _hp_room,
         _sp_room,
         _sitting_regen,
         accumulators,
         _elapsed,
         _multiplier
       ) do
    {0, 0, Map.take(accumulators, [:sitting_hp_acc, :sitting_sp_acc])}
  end

  defp sitting_regen(true, hp_room, sp_room, sitting_regen, accumulators, elapsed, multiplier) do
    hp_amount = sitting_regen.sitting_hp_regen
    sp_amount = sitting_regen.sitting_sp_regen

    if hp_amount > 0 or sp_amount > 0 or Map.has_key?(accumulators, :sitting_hp_acc) or
         Map.has_key?(accumulators, :sitting_sp_acc) do
      {hp_raw, hp_acc} =
        channel(
          hp_room > 0,
          hp_amount,
          100,
          @skill_interval,
          false,
          Map.get(accumulators, :sitting_hp_acc, 0),
          elapsed,
          multiplier
        )

      {sp_raw, sp_acc} =
        channel(
          sp_room > 0,
          sp_amount,
          100,
          @skill_interval,
          false,
          Map.get(accumulators, :sitting_sp_acc, 0),
          elapsed,
          multiplier
        )

      {hp_raw, sp_raw, %{sitting_hp_acc: hp_acc, sitting_sp_acc: sp_acc}}
    else
      {0, 0, %{}}
    end
  end

  @spec channel(
          boolean(),
          integer(),
          integer(),
          pos_integer(),
          boolean(),
          non_neg_integer(),
          non_neg_integer(),
          pos_integer()
        ) :: {non_neg_integer(), non_neg_integer()}
  defp channel(false, _amount, _rate, _base_interval, _sitting?, acc, _elapsed, _multiplier),
    do: {0, acc}

  defp channel(true, amount, rate, _base_interval, _sitting?, acc, _elapsed, _multiplier)
       when rate <= 0 or amount <= 0,
       do: {0, acc}

  defp channel(true, amount, rate, base_interval, sitting?, acc, elapsed, multiplier) do
    multi = if sitting?, do: 2, else: 1
    interval = max(div(base_interval * multiplier * 100, rate * multi), 1)

    progress = acc + elapsed
    intervals = div(progress, interval)
    remainder = rem(progress, interval)

    {intervals * amount, remainder}
  end

  @spec rate(regen_modifiers(), atom()) :: integer()
  defp rate(regen_modifiers, key), do: 100 + Map.get(regen_modifiers, key, 0)

  @spec interval_multiplier(regen_modifiers()) :: pos_integer()
  defp interval_multiplier(regen_modifiers),
    do: max(Map.get(regen_modifiers, :regen_interval_multiplier, 1), 1)

  @spec regen_hp(PlayerStats.t()) :: pos_integer()
  defp regen_hp(%PlayerStats{} = stats) do
    vit = stats.base_stats.vit
    max_hp = stats.derived_stats.max_hp
    div(vit, 5) + max(1, div(max_hp, 200))
  end

  @spec regen_sp(PlayerStats.t()) :: pos_integer()
  defp regen_sp(%PlayerStats{} = stats) do
    int = stats.base_stats.int
    max_sp = stats.derived_stats.max_sp
    base = 1 + div(int, 6) + div(max_sp, 100)

    if int >= 120 do
      base + div(int - 120, 2) + 4
    else
      base
    end
  end
end
