defmodule Aesir.ZoneServer.Unit.Player.NaturalHealTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Unit.Player.NaturalHeal
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Stats

  @no_passive %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: false}

  defp stats(opts) do
    vit = Keyword.get(opts, :vit, 1)
    int = Keyword.get(opts, :int, 1)
    max_hp = Keyword.get(opts, :max_hp, 1000)
    max_sp = Keyword.get(opts, :max_sp, 100)
    hp = Keyword.get(opts, :hp, 1)
    sp = Keyword.get(opts, :sp, 1)
    base_level = Keyword.get(opts, :base_level, 50)

    %PlayerStats{
      base_stats: %Stats.BaseStats{str: 1, agi: 1, vit: vit, int: int, dex: 1, luk: 1},
      derived_stats: %Stats.DerivedStats{max_hp: max_hp, max_sp: max_sp, aspd: 150},
      current_state: %Stats.CurrentState{hp: hp, sp: sp},
      progression: %PlayerStats.PlayerProgression{
        base_level: base_level,
        job_level: 10,
        base_exp: 0,
        job_exp: 0,
        job_id: 1,
        skill_point: 0,
        status_point: 0,
        learned_skills: %{}
      }
    }
  end

  # Enough elapsed for many intervals so an HP amount is emitted in a single call.
  defp acc(elapsed_ms),
    do: %{elapsed_ms: elapsed_ms, hp_acc: 0, sp_acc: 0, skill_hp_acc: 0, skill_sp_acc: 0}

  describe "compute/6 idle vs sitting" do
    test "sitting yields approximately 2x the HP delta of standing-idle for the same elapsed" do
      s = stats(vit: 50, max_hp: 4000, hp: 100)
      elapsed = 60_000

      {idle_hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(elapsed))

      {sit_hp, _sp2, _acc2} =
        NaturalHeal.compute(s, :sitting, :standing, %{}, @no_passive, acc(elapsed))

      assert idle_hp > 0
      assert_in_delta sit_hp / idle_hp, 2.0, 0.25
    end
  end

  describe "compute/6 movement" do
    test "moving yields 0 HP delta without allow_while_moving" do
      s = stats(vit: 50, max_hp: 4000, hp: 100)
      {hp, sp, _acc} = NaturalHeal.compute(s, :idle, :moving, %{}, @no_passive, acc(60_000))
      assert hp == 0
      # SP still regenerates while moving (rAthena: walking does not block SP).
      assert sp > 0
    end

    test "moving yields HP delta when allow_while_moving is true" do
      s = stats(vit: 50, max_hp: 4000, hp: 100)
      passive = %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: true}
      {hp, _sp, _acc} = NaturalHeal.compute(s, :idle, :moving, %{}, passive, acc(60_000))
      assert hp > 0
    end
  end

  describe "compute/6 status regen modifiers" do
    test "hp_regen -100 zeroes the HP delta" do
      s = stats(vit: 50, max_hp: 4000, hp: 100)

      {hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{hp_regen: -100}, @no_passive, acc(60_000))

      assert hp == 0
    end

    test "sp_regen -100 zeroes the SP delta but not HP" do
      s = stats(vit: 50, int: 50, max_hp: 4000, max_sp: 500, hp: 100, sp: 1)

      {hp, sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{sp_regen: -100}, @no_passive, acc(60_000))

      assert sp == 0
      assert hp > 0
    end

    test "positive sp_regen modifier increases the SP delta" do
      s = stats(vit: 50, int: 50, max_hp: 4000, max_sp: 500, hp: 100, sp: 1)

      {_hp, base_sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(60_000))

      {_hp2, boosted_sp, _acc2} =
        NaturalHeal.compute(s, :idle, :standing, %{sp_regen: 100}, @no_passive, acc(60_000))

      assert boosted_sp > base_sp
    end
  end

  describe "compute/6 skill HP regen (SM_RECOVERY)" do
    @skill_passive %{skill_hp_regen: 30, skill_sp_regen: 0, allow_while_moving: false}

    test "a single 10s tick yields the skill amount on top of base regen while standing-idle" do
      s = stats(vit: 1, max_hp: 4000, hp: 100)

      {hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @skill_passive, acc(10_000))

      {base_hp, _sp2, _acc2} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(10_000))

      assert hp - base_hp == 30
    end

    test "skill HP regen also fires while sitting (sitting does not speed it up)" do
      s = stats(vit: 1, max_hp: 4000, hp: 100)

      {idle_hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @skill_passive, acc(10_000))

      {sit_hp, _sp2, _acc2} =
        NaturalHeal.compute(s, :sitting, :standing, %{}, @no_passive, acc(10_000))

      # the skill amount over a single 10s interval is the same whether sitting or
      # standing — only the base HP channel differs (sitting halves its interval)
      {sit_with_skill, _sp3, _acc3} =
        NaturalHeal.compute(s, :sitting, :standing, %{}, @skill_passive, acc(10_000))

      assert idle_hp > 0
      assert sit_with_skill - sit_hp == 30
    end

    test "skill HP regen contributes 0 while moving without allow_while_moving" do
      s = stats(vit: 1, max_hp: 4000, hp: 100)

      {hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :moving, %{}, @skill_passive, acc(10_000))

      assert hp == 0
    end

    test "skill HP regen fires while moving when allow_while_moving is true" do
      s = stats(vit: 1, max_hp: 4000, hp: 100)
      passive = %{skill_hp_regen: 30, skill_sp_regen: 0, allow_while_moving: true}
      base_passive = %{skill_hp_regen: 0, skill_sp_regen: 0, allow_while_moving: true}

      {hp, _sp, _acc} =
        NaturalHeal.compute(s, :idle, :moving, %{}, passive, acc(10_000))

      {base_hp, _sp2, _acc2} =
        NaturalHeal.compute(s, :idle, :moving, %{}, base_passive, acc(10_000))

      assert hp - base_hp == 30
    end
  end

  describe "compute/6 sub-interval accumulation" do
    test "sub-interval regen accumulates across successive calls rather than being lost" do
      s = stats(vit: 50, max_hp: 4000, hp: 100)
      # A short elapsed below one HP interval should heal 0 on its own...
      small = 500

      {hp1, _sp, acc1} =
        NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(small))

      assert hp1 == 0

      # ...but repeated short calls eventually cross the interval and heal.
      {total_hp, _acc_final} =
        Enum.reduce(1..40, {hp1, acc1}, fn _i, {sum, a} ->
          a = %{a | elapsed_ms: small}
          {hp, _sp, a2} = NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, a)
          {sum + hp, a2}
        end)

      assert total_hp > 0
    end
  end

  describe "compute/6 full HP and SP" do
    test "at full HP and SP yields {0, 0, _}" do
      s = stats(vit: 50, int: 50, max_hp: 4000, max_sp: 500, hp: 4000, sp: 500)
      {hp, sp, _acc} = NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(60_000))
      assert hp == 0
      assert sp == 0
    end

    test "HP delta is clamped so it never exceeds max_hp" do
      s = stats(vit: 50, max_hp: 4000, hp: 3990)
      {hp, _sp, _acc} = NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(600_000))
      assert hp <= 10
      assert s.current_state.hp + hp <= s.derived_stats.max_hp
    end
  end

  describe "compute/6 determinism" do
    test "same inputs produce the same output" do
      s = stats(vit: 30, int: 20, max_hp: 3000, max_sp: 300, hp: 50, sp: 10)
      r1 = NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(60_000))
      r2 = NaturalHeal.compute(s, :idle, :standing, %{}, @no_passive, acc(60_000))
      assert r1 == r2
    end
  end
end
