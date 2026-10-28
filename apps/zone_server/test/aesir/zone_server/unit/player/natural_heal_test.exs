defmodule Aesir.ZoneServer.Unit.Player.NaturalHealTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal.Inputs
  alias Aesir.ZoneServer.Unit.Player.NaturalHeal.Timing
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Stats

  @tick 500
  @roomy %{hp: 100, sp: 100, max_hp: 100_000, max_sp: 100_000}

  defp stats(opts) do
    %PlayerStats{
      base_stats: %Stats.BaseStats{
        str: 1,
        agi: 1,
        vit: Keyword.get(opts, :vit, 1),
        int: Keyword.get(opts, :int, 1),
        dex: 1,
        luk: 1
      },
      derived_stats: %Stats.DerivedStats{
        max_hp: Keyword.get(opts, :max_hp, 1000),
        max_sp: Keyword.get(opts, :max_sp, 100),
        aspd: 150
      },
      current_state: %Stats.CurrentState{hp: 1, sp: 1},
      progression: %PlayerStats.PlayerProgression{job_id: 1, learned_skills: %{}},
      modifiers: %PlayerStats.Modifiers{
        equipment: Keyword.get(opts, :equipment, %{}),
        status_effects: %{},
        job_bonuses: %{},
        passive: Keyword.get(opts, :passive, %{})
      }
    }
  end

  defp inputs(opts) do
    %Inputs{
      stats: Keyword.get_lazy(opts, :stats, fn -> stats(opts) end),
      modifiers: Keyword.get(opts, :modifiers, %{}),
      passive_regen: %{
        skill_hp_regen: Keyword.get(opts, :skill_hp, 0),
        skill_sp_regen: Keyword.get(opts, :skill_sp, 0),
        allow_while_moving: Keyword.get(opts, :walk_regen?, false)
      },
      sitting_regen: %{
        sitting_hp_regen: Keyword.get(opts, :sitting_hp, 0),
        sitting_sp_regen: Keyword.get(opts, :sitting_sp, 0)
      },
      no_regen_mask: Keyword.get(opts, :mask, 0),
      sitting?: Keyword.get(opts, :sitting?, false),
      walking?: Keyword.get(opts, :walking?, false),
      overweight?: Keyword.get(opts, :overweight?, false),
      castle_bonus?: Keyword.get(opts, :castle_bonus?, false),
      blocked?: Keyword.get(opts, :blocked?, false),
      tension_relax?: Keyword.get(opts, :tension_relax?, false)
    }
  end

  defp plan(opts), do: opts |> inputs() |> NaturalHeal.plan()

  # Runs `count` ticks (one plan per tick, picked by `plan_for.(n)`) far from
  # full and returns the tick numbers that restored HP and SP.
  defp heal_ticks(plan_for, count, timing \\ Timing.initial()) do
    {_timing, _vitals, hp_ticks, sp_ticks} =
      Enum.reduce(1..count, {timing, @roomy, [], []}, fn n,
                                                         {timing, vitals, hp_ticks, sp_ticks} ->
        {hp, sp, timing} = NaturalHeal.tick(plan_for.(n), timing, @tick, vitals)
        hp_ticks = if hp > 0, do: [n | hp_ticks], else: hp_ticks
        sp_ticks = if sp > 0, do: [n | sp_ticks], else: sp_ticks
        {timing, %{vitals | hp: vitals.hp + hp, sp: vitals.sp + sp}, hp_ticks, sp_ticks}
      end)

    {Enum.reverse(hp_ticks), Enum.reverse(sp_ticks)}
  end

  defp heal_ticks_with(opts, count), do: heal_ticks(fn _n -> plan(opts) end, count)

  describe "tick/4 natural HP cadence" do
    test "heals on ticks 1, 13, 25 standing" do
      assert {[1, 13, 25], _sp} = heal_ticks_with([], 30)
    end

    test "heals on ticks 1, 7, 13 sitting" do
      assert {[1, 7, 13], _sp} = heal_ticks_with([sitting?: true], 18)
    end

    test "an owned guild castle halves the interval like sitting" do
      assert {[1, 7, 13], _sp} = heal_ticks_with([castle_bonus?: true], 18)
    end

    test "heals on ticks 1, 25, 49 walking with walk regeneration" do
      assert {[1, 25, 49], _sp} = heal_ticks_with([walking?: true, walk_regen?: true], 60)
    end

    test "never heals HP walking without walk regeneration, while SP keeps its cadence" do
      assert {[], [1, 17, 33]} = heal_ticks_with([walking?: true], 40)
    end

    test "a blocked tick restarts the count" do
      blocked_at_six = fn n -> plan(blocked?: n == 6) end

      # The block at clock 3000 restarts the 5750 ms interval: due again at 8750.
      assert {[1, 18], _sp} = heal_ticks(blocked_at_six, 20)
      assert {[1, 13], _sp} = heal_ticks_with([], 20)
    end

    test "at full HP the timestamp keeps cycling and the next heal lands on the cycle boundary" do
      plan = plan([])
      full = %{@roomy | hp: 100_000}

      timing =
        Enum.reduce(1..14, Timing.initial(), fn _n, timing ->
          {0, _sp, timing} = NaturalHeal.tick(plan, timing, @tick, full)
          timing
        end)

      assert timing.hp_last_ms == 6_500

      hurt = %{full | hp: 50_000}

      {hp_ticks, _timing} =
        Enum.reduce(15..25, {[], timing}, fn n, {ticks, timing} ->
          {hp, _sp, timing} = NaturalHeal.tick(plan, timing, @tick, hurt)
          {if(hp > 0, do: [n | ticks], else: ticks), timing}
        end)

      assert hp_ticks == [25]
    end
  end

  describe "tick/4 natural SP cadence" do
    test "heals on ticks 1, 17, 33 standing" do
      assert {_hp, [1, 17, 33]} = heal_ticks_with([], 40)
    end

    test "a natural SP interval multiplier of 2 heals on ticks 1 and 33" do
      assert {_hp, [1, 33]} =
               heal_ticks_with([modifiers: %{natural_sp_interval_multiplier: 2}], 40)
    end

    test "Magnificat's tick rate heals on ticks 1, 9, 17" do
      assert {_hp, [1, 9, 17]} = heal_ticks_with([modifiers: %{sp_regen_tick_rate: 100}], 20)
    end
  end

  describe "tick/4 skill regeneration" do
    @skill_only %{no_natural_hp_regen: true, no_natural_sp_regen: true}

    test "skill HP heals every 20 ticks at the base rate" do
      assert {[20, 40], []} = heal_ticks_with([modifiers: @skill_only, skill_hp: 10], 45)
    end

    test "skill HP at triple rate carries the remainder: ticks 7, 14, 20" do
      modifiers = Map.put(@skill_only, :skill_hp_regen_tick_rate, 200)

      assert {[7, 14, 20], []} = heal_ticks_with([modifiers: modifiers, skill_hp: 10], 20)
    end

    test "walking freezes the skill accumulators without resetting them" do
      plan = plan(modifiers: @skill_only, skill_hp: 10, skill_sp: 10, walking?: true)
      timing = %{Timing.initial() | skill_hp_acc: 9_000, skill_sp_acc: 9_000}

      assert {0, 0, %Timing{skill_hp_acc: 9_000, skill_sp_acc: 9_000}} =
               NaturalHeal.tick(plan, timing, @tick, @roomy)
    end

    test "a blocked tick leaves the skill accumulators untouched" do
      plan = plan(skill_hp: 10, skill_sp: 10, blocked?: true)
      timing = %{Timing.initial() | skill_hp_acc: 9_800, skill_sp_acc: 9_800}

      assert {0, 0, %Timing{skill_hp_acc: 9_800, skill_sp_acc: 9_800}} =
               NaturalHeal.tick(plan, timing, @tick, @roomy)
    end

    test "dancing keeps SP Recovery ticking while the natural SP channel is off" do
      assert {[], [20]} =
               heal_ticks_with(
                 [
                   modifiers: %{no_natural_hp_regen: true, no_natural_sp_regen: true},
                   skill_sp: 10
                 ],
                 20
               )
    end
  end

  describe "tick/4 sitting skill regeneration" do
    @sit_only %{no_natural_hp_regen: true, no_natural_sp_regen: true}

    test "heals every 20 sitting ticks" do
      assert {[20, 40], [20, 40]} =
               heal_ticks_with(
                 [modifiers: @sit_only, sitting?: true, sitting_hp: 10, sitting_sp: 5],
                 40
               )
    end

    test "heals every 40 sitting ticks while overweight, nothing else heals" do
      assert {[40], [40]} =
               heal_ticks_with(
                 [sitting?: true, overweight?: true, sitting_hp: 10, sitting_sp: 5],
                 40
               )
    end

    test "heals nothing under no_regen" do
      assert {[], []} =
               heal_ticks_with(
                 [modifiers: %{no_regen: true}, sitting?: true, sitting_hp: 10, sitting_sp: 5],
                 40
               )
    end

    test "does not run standing" do
      assert {[], []} =
               heal_ticks_with([modifiers: @sit_only, sitting_hp: 10, sitting_sp: 5], 40)
    end
  end

  describe "tick/4 ordering" do
    test "partial natural HP heal clamps and skips skill HP for the tick only" do
      # VIT 45 and max HP 200: a natural HP amount of 10 against 3 points of room.
      plan = plan(vit: 45, max_hp: 200, skill_hp: 5)
      assert plan.hp == 10

      timing = %{Timing.initial() | skill_hp_acc: 9_500}
      vitals = %{hp: 197, sp: 100, max_hp: 200, max_sp: 100}

      {hp, sp, timing} = NaturalHeal.tick(plan, timing, @tick, vitals)

      assert {hp, sp} == {3, 0}
      assert timing.skill_hp_acc == 9_500

      {hp, _sp, timing} = NaturalHeal.tick(plan, timing, @tick, %{vitals | hp: 150})

      assert hp == 5
      assert timing.skill_hp_acc == 0
    end

    test "a dead tick heals nothing and resets only the natural timestamps" do
      plan = plan(skill_hp: 10, sitting?: true, sitting_hp: 10, blocked?: true)

      timing = %Timing{
        clock_ms: 4_000,
        hp_last_ms: 1_000,
        sp_last_ms: 2_000,
        skill_hp_acc: 3_000,
        skill_sp_acc: 4_000,
        sitting_hp_acc: 5_000,
        sitting_sp_acc: 6_000
      }

      assert NaturalHeal.tick(plan, timing, @tick, @roomy) ==
               {0, 0, %{timing | clock_ms: 4_500, hp_last_ms: 4_500, sp_last_ms: 4_500}}
    end

    test "sitting regen runs before the walking gate clears the skill flags" do
      plan = plan(sitting?: true, walking?: true, sitting_hp: 7, modifiers: @sit_only)
      timing = %{Timing.initial() | sitting_hp_acc: 9_500}

      assert {7, 0, %Timing{sitting_hp_acc: 0}} = NaturalHeal.tick(plan, timing, @tick, @roomy)
    end

    test "a partial sitting heal stops the skill HP channel for the tick" do
      plan = plan(sitting?: true, sitting_hp: 10, skill_hp: 10, modifiers: @sit_only)
      timing = %{Timing.initial() | sitting_hp_acc: 9_500, skill_hp_acc: 9_500}
      vitals = %{@roomy | hp: 99_995}

      assert {5, 0, %Timing{sitting_hp_acc: 0, skill_hp_acc: 9_500}} =
               NaturalHeal.tick(plan, timing, @tick, vitals)
    end
  end

  describe "plan/1 amounts" do
    test "natural HP is vit/5 + max(1, max_hp/200) scaled by the recovery rate, floored at 0" do
      assert plan(vit: 50, max_hp: 4_000).hp == 10 + 20
      assert plan(vit: 50, max_hp: 4_000, modifiers: %{hp_regen: 50}).hp == 45
      assert plan(vit: 50, max_hp: 4_000, modifiers: %{hp_regen: -100}).hp == 0
      assert plan(vit: 50, max_hp: 4_000, modifiers: %{hp_regen: -150}).hp == 0
      assert plan(vit: 1, max_hp: 100).hp == 1
    end

    test "natural HP reads effective VIT" do
      assert plan(vit: 50, max_hp: 4_000, equipment: %{vit: 10}).hp == 12 + 20
    end

    test "natural SP adds the INT 120 bonus" do
      assert plan(int: 60, max_sp: 500).sp == 1 + 10 + 5
      assert plan(int: 130, max_sp: 500).sp == 1 + 21 + 5 + 5 + 4
    end

    test "Meditatio applies after the recovery rate with a floor of 1" do
      assert plan(int: 60, max_sp: 500, passive: %{sp_regen_rate: 30}).sp == div(16 * 130, 100)

      assert plan(
               int: 60,
               max_sp: 500,
               modifiers: %{sp_regen: -100},
               passive: %{sp_regen_rate: 30}
             ).sp == 1

      assert plan(int: 60, max_sp: 500, modifiers: %{sp_regen: -100}).sp == 0
    end
  end

  describe "plan/1 flags and rates" do
    test "no_regen clears every channel" do
      plan = plan(modifiers: %{no_regen: true}, skill_hp: 5, skill_sp: 5)

      assert {plan.natural_hp?, plan.natural_sp?, plan.skill_hp?, plan.skill_sp?} ==
               {false, false, false, false}
    end

    test "no_natural_sp_regen clears only natural SP" do
      plan = plan(modifiers: %{no_natural_sp_regen: true}, skill_hp: 5, skill_sp: 5)

      assert {plan.natural_hp?, plan.natural_sp?, plan.skill_hp?, plan.skill_sp?} ==
               {true, false, true, true}
    end

    test "the equipment mask clears natural and skill channels per resource" do
      hp_masked = plan(mask: 1, skill_hp: 5, skill_sp: 5)
      sp_masked = plan(mask: 2, skill_hp: 5, skill_sp: 5)

      assert {hp_masked.natural_hp?, hp_masked.skill_hp?, hp_masked.natural_sp?,
              hp_masked.skill_sp?} == {false, false, true, true}

      assert {sp_masked.natural_hp?, sp_masked.skill_hp?, sp_masked.natural_sp?,
              sp_masked.skill_sp?} == {true, true, false, false}
    end

    test "the skill flag is set by either the skill or the sitting amount" do
      assert plan(sitting_hp: 5).skill_hp?
      assert plan(sitting_sp: 5).skill_sp?
      refute plan([]).skill_hp?
    end

    test "Tension Relax raises the HP tick rates unless overweight" do
      modifiers = %{hp_regen_tick_rate: 200, skill_hp_regen_tick_rate: 200}
      relaxed = plan(modifiers: modifiers, tension_relax?: true)
      overweight = plan(modifiers: modifiers, tension_relax?: true, overweight?: true)

      assert {relaxed.hp_rate, relaxed.skill_hp_rate, relaxed.overweight?} == {300, 300, false}

      assert {overweight.hp_rate, overweight.skill_hp_rate, overweight.overweight?} ==
               {100, 100, false}
    end

    test "overweight without Tension Relax stays overweight" do
      assert plan(overweight?: true).overweight?
    end
  end
end
