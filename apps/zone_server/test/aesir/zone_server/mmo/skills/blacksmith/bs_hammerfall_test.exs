defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfallTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHammerfall
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stun
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  test "defines the five-level no-damage 5x5 skill at a flat 10 SP" do
    definition = BsHammerfall.definition()

    assert definition.target_type == :ground
    assert definition.damage_type == :no_damage
    assert definition.splash_radius == 2
    assert definition.sp_cost == List.duplicate(10, 5)
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

  test "stun's existing physical resistance path lowers chance and duration as VIT rises" do
    definition = Stun.metadata()

    {low_vit_chance, low_vit_duration} =
      Resistance.apply_resistance(definition, %{vit: 0, luk: 0}, 70, 4_500)

    {high_vit_chance, high_vit_duration} =
      Resistance.apply_resistance(definition, %{vit: 50, luk: 0}, 70, 4_500)

    assert high_vit_chance < low_vit_chance
    assert high_vit_duration < low_vit_duration
  end

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
end
