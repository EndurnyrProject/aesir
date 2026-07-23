defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtremityFistRecoveryTest do
  use ExUnit.Case, async: true
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.ExtremityFistRecovery
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :set_mimic_from_context
  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(Resistance)
    Mimic.copy(UnitRegistry)

    stub(UnitRegistry, :get_unit_info, fn :player, player_id ->
      {:ok,
       %{
         unit_id: player_id,
         unit_type: :player,
         race: :human,
         element: :neutral,
         element_level: 1,
         boss_flag: false,
         size: :medium,
         stats: %{max_hp: 1_000, max_sp: 100, hp: 800, sp: 0}
       }}
    end)

    stub(Resistance, :roll_success, fn _ -> true end)
    :ok
  end

  test "carries the verified Renewal recovery metadata" do
    metadata = ExtremityFistRecovery.metadata()

    assert ExtremityFistRecovery.id() == :sc_extremityfist
    assert metadata.duration == Formulas.asura_recovery_duration()
    assert metadata.duration == 3_000
    assert metadata.no_save
    assert metadata.no_dispel
    assert metadata.bypass_resistance
    assert :regen in metadata.calc_flags
    assert metadata.icon == :extremityfist
  end

  test "suppresses only spirit-point regeneration" do
    entry = %StatusEntry{type: :sc_extremityfist, val1: 5, state: %{}}

    assert ExtremityFistRecovery.modifiers(entry, %{}) == %{sp_regen: -100}
  end

  test "blocks spirit-point regen for its full duration and clears on removal" do
    player_id = 7_100

    assert :ok =
             Interpreter.apply_status(:player, player_id, :sc_extremityfist,
               val1: 5,
               caster_id: player_id,
               duration: Formulas.asura_recovery_duration()
             )

    assert Interpreter.get_all_modifiers(:player, player_id) == %{sp_regen: -100}

    assert :ok = Interpreter.remove_status(:player, player_id, :sc_extremityfist)
    assert Interpreter.get_all_modifiers(:player, player_id) == %{}
  end
end
