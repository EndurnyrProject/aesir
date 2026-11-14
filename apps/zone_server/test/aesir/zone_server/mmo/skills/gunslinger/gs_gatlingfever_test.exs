defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGatlingfeverTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsGatlingfever
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.GatlingFever
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Removal
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @id 101

  test "gatlingfever channels use the mode's ATK and ASPD stages" do
    entry = %StatusEntry{type: :sc_gatlingfever, val1: 5, val2: 100, val3: 70, val4: 25}

    expected =
      if GameMode.mode() == :renewal,
        do: %{post_card_equip_atk: 70, aspd: 5, flee: -25, movement_speed: 100},
        else: %{batk: 70, aspd_rate_max: 10, flee: -25, movement_speed: 100}

    assert GatlingFever.modifiers(entry, %{}) == expected
  end

  test "gatlingfever toggle skips weapon and SP costs when held" do
    caster = PlayerStateFixture.build(%{character_id: @id, stats: %{current_state: %{sp: 0}}})
    :ok = StatusStorage.apply_status(:player, @id, :sc_gatlingfever, val1: 5)
    assert Caster.Player.toggle_off?(caster, GsGatlingfever.definition())
    assert {:ok, ^caster} = GsGatlingfever.cast(caster, :self, 5, GsGatlingfever.definition())
    refute StatusStorage.has_status?(:player, @id, :sc_gatlingfever)
  end

  test "gatlingfever toggle-off cast spends nothing without the Gatling" do
    caster = bare_caster()
    :ok = StatusStorage.apply_status(:player, @id, :sc_gatlingfever, val1: 5)

    assert {:ok, updated} = SkillInterpreter.cast(caster, 517, 5, :self)
    assert updated.stats.current_state.sp == 0
    refute StatusStorage.has_status?(:player, @id, :sc_gatlingfever)
  end

  test "gatlingfever first cast without the Gatling is refused and spends nothing" do
    caster = bare_caster()

    assert {:error, :wrong_weapon} = SkillInterpreter.cast(caster, 517, 5, :self)
    refute StatusStorage.has_status?(:player, @id, :sc_gatlingfever)
  end

  test "gatlingfever slowdown and classic ASPD compete by maximum" do
    entry = %StatusEntry{type: :sc_gatlingfever, val1: 5, val2: 100, val3: 70, val4: 25}
    modifiers = GatlingFever.modifiers(entry, %{})

    result =
      ModifierCalculator.merge_modifiers(%{movement_speed: 75, aspd_rate_max: 20}, modifiers)

    assert result.movement_speed == 100
    assert result.aspd_rate_max == 20
    assert result.flee == -25
  end

  test "gatlingfever weapon is required and removing it ends the status" do
    caster = bare_caster()

    assert {:error, :wrong_weapon} =
             Caster.Player.check_weapon(caster, GsGatlingfever.definition())

    assert {:error, :wrong_weapon} =
             Caster.Player.castend_cost(
               caster,
               GsGatlingfever,
               :self,
               GsGatlingfever.definition(),
               1
             )

    :ok = StatusStorage.apply_status(:player, @id, :sc_gatlingfever, val1: 5)
    Removal.enforce_weapon_requirements(:player, @id, :fist)
    refute StatusStorage.has_status?(:player, @id, :sc_gatlingfever)
  end

  defp bare_caster do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    caster =
      PlayerStateFixture.build(%{
        character_id: @id,
        x: 10,
        y: 10,
        map_name: "prontera",
        stats: %{
          current_state: %{hp: 100, sp: 0},
          combat_stats: %CombatStats{},
          equipment: %{right_hand: nil},
          progression: %{learned_skills: %{517 => 5}}
        }
      })

    :ok =
      UnitRegistry.register_unit(
        :player,
        @id,
        Aesir.ZoneServer.Unit.Player.PlayerState,
        caster,
        self()
      )

    caster
  end
end
