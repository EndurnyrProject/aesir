defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfallTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.CastEnd
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  test "stuns for 4.5 seconds in renewal and 5 seconds in classic" do
    assert BsHammerfall.definition(:renewal).duration == List.duplicate(4_500, 5)
    assert BsHammerfall.definition(:pre_renewal).duration == List.duplicate(5_000, 5)
  end

  @tag game_mode: :pre_renewal
  test "classic impacts stun for 5 seconds" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 10, y: 20}

    expect(Combat, :splash_targets, fn "prontera", {30, 40}, 2, 1_000 -> [{:mob, 2_003}] end)

    expect(StatusInterpreter, :apply_status, fn :mob,
                                                2_003,
                                                :sc_stun,
                                                [
                                                  caster_id: 1_000,
                                                  val1: 3,
                                                  duration: 5_000,
                                                  success_rate: 50
                                                ] ->
      :ok
    end)

    payload = %{caster_id: 1_000, map_name: "prontera", center: {30, 40}, level: 3}
    assert :ok = BsHammerfall.deferred(payload, caster)
  end

  test "schedules the impact one second after casting" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 10, y: 20}

    assert {:ok, ^caster} =
             BsHammerfall.cast(caster, {:ground, 30, 40}, 3, BsHammerfall.definition())

    refute_receive {:skill, {:deferred, BsHammerfall, _payload}}, 100

    assert_receive {:skill,
                    {:deferred, BsHammerfall,
                     %{caster_id: 1_000, map_name: "prontera", center: {30, 40}, level: 3}}},
                   1_100
  end

  test "stun's status defense lowers chance and duration as VIT rises" do
    test_pid = self()

    attempt = fn vit ->
      view = %{
        player?: false,
        level: 50,
        str: 0,
        agi: 0,
        vit: vit,
        int: 0,
        dex: 0,
        luk: 0,
        mdef: 0
      }

      %{
        status: :sc_stun,
        rate: 7000,
        tick: 4500,
        target: view,
        source: %{view | vit: 0},
        scresist: nil,
        siegfried: nil,
        res_eff: 0,
        roll: fn rate ->
          send(test_pid, {:rate, rate})
          true
        end
      }
      |> Resistance.defend(GameMode.mode())
    end

    {:ok, low_vit_duration} = attempt.(0)
    assert_received {:rate, low_vit_chance}
    {:ok, high_vit_duration} = attempt.(50)
    assert_received {:rate, high_vit_chance}

    assert high_vit_chance < low_vit_chance
    assert high_vit_duration < low_vit_duration
  end

  @tag game_mode: :renewal
  test "delayed impacts attempt level-scaled stun on mobs without dealing damage" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 10, y: 20}
    chances = [30, 40, 50, 60, 70]

    reject(&Combat.apply_skill_unit_damage/7)
    reject(&Combat.execute_skill_attack/3)

    for {chance, level} <- Enum.with_index(chances, 1) do
      expect(Combat, :splash_targets, fn "prontera", {30, 40}, 2, 1_000 ->
        [{:mob, 2_000 + level}, {:player, 3_000 + level}]
      end)

      expect(StatusInterpreter, :apply_status, fn
        :mob,
        target_id,
        :sc_stun,
        [caster_id: 1_000, val1: ^level, duration: 4_500, success_rate: ^chance] ->
          assert target_id == 2_000 + level
          :ok
      end)

      payload = %{caster_id: 1_000, map_name: "prontera", center: {30, 40}, level: level}
      assert :ok = BsHammerfall.deferred(payload, caster)
    end
  end

  test "arms the cast-end tail of the area's enemies when the cast ends" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 10, y: 20}

    stub(Combat, :splash_targets, fn "prontera", {30, 40}, 2, 1_000 -> [{:mob, 2_003}] end)

    test_pid = self()

    stub(CastEnd, :complete_target, fn _caster, 110, {:unit, {:mob, id}}, on_skill: true ->
      send(test_pid, {:tail, id})
      :ok
    end)

    assert {:ok, ^caster} =
             BsHammerfall.cast(caster, {:ground, 30, 40}, 3, BsHammerfall.definition())

    assert_received {:tail, 2_003}
  end

  test "only the stun is delayed: the delayed impact runs no cast-end tail" do
    caster = %PlayerState{character_id: 1_000, map_name: "prontera", x: 10, y: 20}

    stub(Combat, :splash_targets, fn "prontera", {30, 40}, 2, 1_000 -> [{:mob, 2_003}] end)
    reject(&CastEnd.complete_target/4)

    expect(StatusInterpreter, :apply_status, fn :mob, 2_003, :sc_stun, _opts -> :ok end)

    payload = %{caster_id: 1_000, map_name: "prontera", center: {30, 40}, level: 3}

    assert :ok = BsHammerfall.deferred(payload, caster)
  end
end
