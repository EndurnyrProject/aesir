defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDisarmTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.Net.SkillEffect
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsDisarm
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  setup do
    Mimic.copy(PlayerState)
    Mimic.copy(MobState)
    Mimic.copy(StripCommon)
    :ok
  end

  @caster_id 1_000
  @target_id 7

  test "disarm_rate_test: the reference formula at every level" do
    caster = %{dex: 100, luk: 40, level: 99}
    target = %{agi: 50, luk: 10, level: 50}

    assert Enum.map(1..5, &GsDisarm.rate(&1, caster, target)) == [42, 43, 44, 46, 50]
    assert GsDisarm.rate(5, %{caster | level: 1}, target) == -48
  end

  test "disarm_rate_test: success only when the 0..99 roll is below the rate" do
    assert StripCommon.percent_success?(49, 50)
    refute StripCommon.percent_success?(50, 50)
    refute StripCommon.percent_success?(0, 0)
    refute StripCommon.percent_success?(0, -48)
    assert StripCommon.percent_success?(99, 100)
  end

  test "disarm_duration_test: a flat 30 s on a mob, val1 the level, no DEX bonus" do
    arrange_hit(mob_target())
    stub(StripCommon, :roll_percent?, fn 50 -> true end)
    stub(StatusStorage, :has_status?, fn :mob, @target_id, _status -> false end)
    expect_effect()

    expect(StatusInterpreter, :apply_status, fn :mob, @target_id, :sc_stripweapon, opts ->
      assert Keyword.equal?(opts,
               bypass_resistance: true,
               duration: 30_000,
               val1: 5,
               caster_id: @caster_id,
               source_type: :player
             )

      :ok
    end)

    assert {:ok, _caster} = cast(5)
    assert GsDisarm.duration_ms() == 30_000
  end

  test "disarm_duration_test: a player target gets the same flat duration" do
    target = %PlayerState{character_id: @target_id, map_name: "prontera", x: 12, y: 10}
    stub(Combat, :execute_skill_attack, fn _caster, {:player, @target_id}, _opts -> hit() end)
    stub(TargetResolver, :resolve, fn {:player, @target_id} -> {:ok, self(), target, :player} end)
    stub(PlayerState, :get_stats, fn %PlayerState{character_id: id} -> stats_for(id) end)
    stub(StripCommon, :roll_percent?, fn _rate -> true end)

    expect(PlayerSession, :strip_equip, fn _pid, [:right_hand], opts ->
      assert opts[:duration] == 30_000
      assert opts[:val1] == 2
      assert opts[:kind] == :disarm
      :ok
    end)

    assert {:ok, _caster} =
             GsDisarm.cast(caster(), {:unit, {:player, @target_id}}, 2, GsDisarm.definition())
  end

  test "disarm_outcome_test: a failed roll shows the success visual and reports nothing" do
    arrange_hit(mob_target())
    stub(StripCommon, :roll_percent?, fn _rate -> false end)
    reject(&StatusInterpreter.apply_status/4)
    reject(&SkillHandler.report_cast_failure/3)
    expect_effect()

    assert {:ok, _caster} = cast(5)
  end

  test "disarm_outcome_test: a chemical-protected target is skipped" do
    arrange_hit(mob_target())
    stub(StripCommon, :roll_percent?, fn _rate -> true end)
    stub(StatusStorage, :has_status?, fn :mob, @target_id, status -> status == :sc_cp_weapon end)
    reject(&StatusInterpreter.apply_status/4)
    reject(&SkillHandler.report_cast_failure/3)
    expect_effect()

    assert {:ok, _caster} = cast(5)
  end

  test "disarm_outcome_test: a player target's empty strip still shows success" do
    reject(&SkillHandler.report_cast_failure/3)
    expect_effect()

    assert :ok =
             StripCommon.report_outcome(false,
               skill_id: 513,
               level: 3,
               kind: :disarm,
               src_id: @caster_id,
               target_id: @target_id,
               origin: {"prontera", 12, 10},
               report_to: @caster_id
             )
  end

  test "a missed or killing hit rolls nothing" do
    for report <- [
          %{hit?: false, target_survives?: true},
          %{hit?: true, target_survives?: false}
        ] do
      stub(Combat, :execute_skill_attack, fn _caster, _target, _opts -> {:ok, report} end)
      reject(&StripCommon.roll_percent?/1)
      reject(&Broadcast.to_in_range/5)

      assert {:ok, _caster} = cast(1)
    end
  end

  test "divest_unchanged_test: per-mille rate, DEX-scaled duration and failure report" do
    assert StripCommon.strip_success_rate(5, 90, 40) == 400
    assert StripCommon.strip_duration_ms(3, 70, 50, :mob) == 130_003
    expect(SkillHandler, :report_cast_failure, fn 215, @caster_id, :skill_failed -> :ok end)

    expect(Broadcast, :to_in_range, fn "prontera", 12, 10, _range, packet ->
      assert %SkillEffect{skill_id: 215, result: 0} = packet
      :ok
    end)

    assert :ok =
             StripCommon.report_outcome(false,
               skill_id: 215,
               level: 1,
               kind: :divest,
               src_id: @caster_id,
               target_id: @target_id,
               origin: {"prontera", 12, 10},
               report_to: @caster_id
             )
  end

  defp cast(level),
    do: GsDisarm.cast(caster(), {:unit, {:mob, @target_id}}, level, GsDisarm.definition())

  defp arrange_hit(target) do
    expect(Combat, :execute_skill_attack, fn _caster, {:mob, @target_id}, opts ->
      assert opts[:skill_ratio] == 100 and opts[:report_hit] and opts[:skip_crit]
      hit()
    end)

    stub(TargetResolver, :resolve, fn {:mob, @target_id} -> {:ok, self(), target, :mob} end)
    stub(PlayerState, :get_stats, fn %PlayerState{character_id: id} -> stats_for(id) end)
    stub(MobState, :get_stats, fn _mob -> stats_for(@target_id) end)
  end

  defp hit, do: {:ok, %{hit?: true, target_survives?: true}}

  defp expect_effect do
    expect(Broadcast, :to_in_range, fn "prontera", 12, 10, _range, packet ->
      assert %SkillEffect{src_id: @caster_id, target_id: @target_id, result: 1} = packet
      :ok
    end)
  end

  defp stats_for(@caster_id),
    do: %{total_stats: %{dex: 100, agi: 1, luk: 40}, base_level: 99, dex: 1, luk: 1}

  defp stats_for(@target_id),
    do: %{total_stats: %{dex: 1, agi: 50, luk: 10}, base_level: 50, agi: 1, luk: 1}

  defp caster, do: %PlayerState{character_id: @caster_id, map_name: "prontera", x: 10, y: 10}

  defp mob_target do
    %MobState{
      instance_id: @target_id,
      mob_id: 1_002,
      mob_data: Aesir.TestMob.definition(),
      spawn_ref: nil,
      map_name: "prontera",
      x: 12,
      y: 10,
      hp: 100,
      sp: 100,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: 100, max_sp: 100)
  end
end
