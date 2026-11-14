defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GunslingerBusterRidersTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsFullbuster
  alias Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsPiercingshot
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Stats.CombatStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_private
  setup :verify_on_exit!
  setup :setup_ets_tables

  @caster_id 101
  @target_id 7

  test "fullbuster_ammo_test" do
    amounts =
      for level <- 1..10, do: Definition.ammo_qty_at_level(GsFullbuster.definition(), level)

    assert amounts ==
             if(GameMode.mode() == :renewal,
               do: List.duplicate(2, 10),
               else: [2, 2, 4, 4, 6, 6, 8, 8, 10, 10]
             )
  end

  test "fullbuster_self_blind_test: the caster's own resistance decides" do
    caster = registered_caster()
    stub_damage(%{hit?: true, damage: 10, target_survives?: false})

    for {resist, blinded?} <- [{false, true}, {true, false}] do
      StatusStorage.remove_status(:player, @caster_id, :sc_blind)
      stub_resistance(resist)

      assert {:ok, _caster} =
               GsFullbuster.cast(
                 caster,
                 {:unit, {:mob, @target_id}},
                 5,
                 GsFullbuster.definition()
               )

      assert StatusStorage.has_status?(:player, @caster_id, :sc_blind) == blinded?
    end
  end

  test "fullbuster_self_blind_test: a miss or a zero-damage hit blinds nobody" do
    caster = registered_caster()
    stub_resistance(false)
    reject(&StatusInterpreter.apply_status/4)

    for report <- [%{hit?: false, damage: 0}, %{hit?: true, damage: 0}] do
      stub_damage(report)

      assert {:ok, _caster} =
               GsFullbuster.cast(
                 caster,
                 {:unit, {:mob, @target_id}},
                 5,
                 GsFullbuster.definition()
               )
    end
  end

  test "fullbuster_self_blind_test: ten seconds at twice the level percent" do
    caster = registered_caster()
    stub_damage(%{hit?: true, damage: 10})

    expect(StatusInterpreter, :apply_status, fn :player, @caster_id, :sc_blind, opts ->
      assert opts[:success_rate] == 10
      assert opts[:duration] == 10_000
      assert opts[:caster_id] == @caster_id
      {:error, :resisted}
    end)

    assert {:ok, _caster} =
             GsFullbuster.cast(caster, {:unit, {:mob, @target_id}}, 5, GsFullbuster.definition())
  end

  test "piercingshot_bleed_test: the target's resistance decides" do
    caster = registered_caster()
    stub_damage(%{hit?: true, target_survives?: true})
    stub_target_combatant()

    for {resist, bleeding?} <- [{false, true}, {true, false}] do
      StatusStorage.remove_status(:player, @target_id, :sc_bleeding)
      stub_resistance(resist)

      assert {:ok, _caster} =
               GsPiercingshot.cast(
                 caster,
                 {:unit, {:player, @target_id}},
                 5,
                 GsPiercingshot.definition()
               )

      assert StatusStorage.has_status?(:player, @target_id, :sc_bleeding) == bleeding?
    end
  end

  test "piercingshot_bleed_test: three percent per level with the mode's duration" do
    caster = registered_caster()
    stub_damage(%{hit?: true, target_survives?: true})
    stub_target_combatant()

    expect(StatusInterpreter, :apply_status, fn :player, @target_id, :sc_bleeding, opts ->
      assert opts[:success_rate] == 15
      assert opts[:duration] == if(GameMode.mode() == :renewal, do: 108_000, else: 120_000)
      {:error, :resisted}
    end)

    assert {:ok, _caster} =
             GsPiercingshot.cast(
               caster,
               {:unit, {:player, @target_id}},
               5,
               GsPiercingshot.definition()
             )
  end

  test "piercingshot_bleed_test: a killing hit does not bleed" do
    caster = registered_caster()
    stub_damage(%{hit?: true, target_survives?: false})
    reject(&StatusInterpreter.apply_status/4)

    assert {:ok, _caster} =
             GsPiercingshot.cast(
               caster,
               {:unit, {:player, @target_id}},
               5,
               GsPiercingshot.definition()
             )
  end

  defp registered_caster do
    caster =
      PlayerStateFixture.build(%{
        character_id: @caster_id,
        x: 10,
        y: 10,
        map_name: "prontera",
        stats: %{combat_stats: %CombatStats{}}
      })

    :ok = UnitRegistry.register_unit(:player, @caster_id, PlayerState, caster, self())

    :ok =
      UnitRegistry.register_unit(
        :player,
        @target_id,
        PlayerState,
        %{caster | character_id: @target_id},
        self()
      )

    caster
  end

  defp stub_damage(report) do
    stub(Combat, :execute_skill_attack, fn _caster, _target, _opts -> {:ok, report} end)
  end

  defp stub_target_combatant do
    stub(TargetResolver, :resolve_combatant, fn {:player, @target_id} ->
      {:ok, %{unit_type: :player, unit_id: @target_id}}
    end)
  end

  defp stub_resistance(resist) do
    stub(Resistance, :roll_rate, fn _rate -> not resist end)
    stub(Resistance, :roll_success, fn _rate -> not resist end)
  end
end
