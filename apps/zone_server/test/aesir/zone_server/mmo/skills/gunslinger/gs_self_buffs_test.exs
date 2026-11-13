defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsSelfBuffsTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter, as: SkillInterpreter
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsMadnesscancel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Increasing
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.MadnessCancel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Permissions
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @target 4_343
  @madness %StatusEntry{type: :sc_madnesscancel, val1: 1}

  describe "madness_channels" do
    @tag game_mode: :renewal
    test "renewal adds 100 equipment ATK and floors the flat ASPD bonus at 20" do
      assert MadnessCancel.modifiers(@madness, %{}) ==
               %{post_card_equip_atk: 100, aspd_rate_strongest: 20}
    end

    @tag game_mode: :pre_renewal
    test "pre-renewal adds 100 base ATK and the 20 percent rate" do
      assert MadnessCancel.modifiers(@madness, %{}) == %{batk: 100, aspd_rate_strongest: 20}
    end

    test "the holder cannot move" do
      player()
      apply!(:sc_madnesscancel)
      refute Permissions.can_move?(:player, @target)
    end
  end

  describe "madness_recast" do
    test "recasting while held ends the status without restarting it" do
      caster = player()
      definition = GsMadnesscancel.definition()

      assert {:ok, ^caster} = GsMadnesscancel.cast(caster, :self, 1, definition)
      assert StatusStorage.has_status?(:player, @target, :sc_madnesscancel)

      assert {:ok, ^caster} = GsMadnesscancel.cast(caster, :self, 1, definition)
      refute StatusStorage.has_status?(:player, @target, :sc_madnesscancel)
    end
  end

  test "madness recast pays SP and coins through the ordinary cast path" do
    player()
    apply!(:sc_madnesscancel)

    spheres =
      Enum.reduce(1..5, SpiritSpheres.new(), fn _, spheres ->
        {spheres, _entry} = SpiritSpheres.summon(spheres, 60_000, 5)
        spheres
      end)

    caster =
      PlayerStateFixture.build(%{
        character_id: @target,
        x: 10,
        y: 10,
        map_name: "prontera",
        spirit_spheres: spheres,
        stats: %{current_state: %{hp: 100, sp: 100}, progression: %{learned_skills: %{504 => 1}}}
      })

    assert {:ok, updated} = SkillInterpreter.cast(caster, 504, 1, :self)
    assert updated.stats.current_state.sp == 70
    expected_coins = if GameMode.mode() == :renewal, do: 4, else: 1
    assert SpiritSpheres.count(updated.spirit_spheres) == expected_coins
    refute StatusStorage.has_status?(:player, @target, :sc_madnesscancel)
  end

  describe "madness_adjustment_pair" do
    test "starting either ends the other" do
      player()
      apply!(:sc_adjustment)
      apply!(:sc_madnesscancel)
      refute StatusStorage.has_status?(:player, @target, :sc_adjustment)

      apply!(:sc_adjustment)
      refute StatusStorage.has_status?(:player, @target, :sc_madnesscancel)
      assert StatusStorage.has_status?(:player, @target, :sc_adjustment)
    end
  end

  describe "adjustment_absorb" do
    test "cuts a long-range weapon hit by 20 percent after Defender and before Blinding Mist" do
      player()
      apply!(:sc_fogwall)
      apply!(:sc_defender, val1: 1)
      apply!(:sc_adjustment)

      hit = %{dmg_type: :physical, is_short: false, skill_id: nil}
      assert Interpreter.absorb_damage(:player, @target, 1_000, hit) == 160

      Interpreter.remove_status(:player, @target, :sc_defender)
      apply!(:sc_defender, val1: 2)
      skill_hit = %{dmg_type: :physical, is_short: false, skill_id: 1}
      assert Interpreter.absorb_damage(:player, @target, 11, skill_hit) == 6
    end

    test "leaves short-range and magic hits untouched" do
      player()
      apply!(:sc_adjustment)

      for hit <- [
            %{dmg_type: :physical, is_short: true, skill_id: nil},
            %{dmg_type: :magic, is_short: false, skill_id: 19}
          ] do
        assert Interpreter.absorb_damage(:player, @target, 1_000, hit) == 1_000
      end
    end
  end

  describe "increasing" do
    test "grants AGI 4, DEX 4 and HIT 20" do
      assert Increasing.modifiers(%StatusEntry{type: :sc_increasing, val1: 1}, %{}) ==
               %{agi: 4, dex: 4, hit: 20}
    end

    test "is not a Clearance target" do
      assert :no_clearance in Increasing.metadata().flags
    end
  end

  defp apply!(status_id, params \\ []) do
    :ok = Interpreter.apply_status(:player, @target, status_id, params)
  end

  defp player do
    Mimic.copy(Resistance)
    stub(Resistance, :roll_success, fn _ -> true end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    pid = spawn(fn -> Process.sleep(:infinity) end)
    stats = %{max_hp: 1_000, hp: 1_000, sp: 100, max_sp: 100, level: 50, base_level: 50}

    stub(UnitRegistry, :get_unit_info, fn _unit_type, _unit_id ->
      {:ok,
       %{
         unit_id: @target,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: stats
       }}
    end)

    state = %PlayerState{
      character_id: @target,
      action_state: :idle,
      stats: %{current_state: stats}
    }

    stub(UnitRegistry, :get_unit, fn
      :player, @target -> {:ok, {PlayerState, state, pid}}
      _type, _id -> {:error, :not_found}
    end)

    state
  end
end
