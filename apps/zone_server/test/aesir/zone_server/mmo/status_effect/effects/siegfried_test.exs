defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.SiegfriedTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.MagicDamageCalculator
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Siegfried
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @defender_id 31_300

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    Mimic.copy(UnitRegistry)
    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)
    :ok
  end

  test "declares the canonical ensemble exclusion list and 180 second duration" do
    assert Siegfried.metadata().end_on_start == [
             :sc_richmankim,
             :sc_eternalchaos,
             :sc_drumbattle,
             :sc_nibelungen,
             :sc_rokisweil,
             :sc_intoabyss,
             :sc_siegfried
           ]

    assert Siegfried.metadata().duration == 180_000
  end

  test "reduces Water, Earth, Fire and Wind damage by three percent per effective level" do
    apply_siegfried()

    for element <- [:water, :earth, :fire, :wind] do
      assert damage(element) == 85
    end
  end

  test "does not reduce Holy, Shadow, Poison, Ghost, Undead or Neutral damage" do
    elements = [:holy, :shadow, :poison, :ghost, :undead, :neutral]
    baseline = Map.new(elements, &{&1, damage(&1)})
    apply_siegfried()

    for element <- elements do
      assert damage(element) == baseline[element]
    end
  end

  test "reduces ailment application rate without affecting buffs" do
    test_pid = self()
    apply_siegfried()

    assert {:error, :resisted} =
             Interpreter.apply_status(:player, @defender_id, :sc_freeze,
               success_rate: 100,
               resistance_roll: fn final_rate ->
                 send(test_pid, {:ailment_rate, final_rate})
                 false
               end
             )

    assert_received {:ailment_rate, 75.0}

    assert :ok =
             Interpreter.apply_status(:player, @defender_id, :sc_hiding,
               success_rate: 63,
               resistance_roll: fn final_rate ->
                 send(test_pid, {:buff_rate, final_rate})
                 true
               end
             )

    assert_received {:buff_rate, 63.0}
  end

  defp apply_siegfried do
    :ok =
      StatusStorage.apply_status(:player, @defender_id, :sc_siegfried,
        val1: 15,
        val2: 25,
        duration: 180_000
      )
  end

  defp damage(element) do
    attacker = combatant(:mob, 31_301, %{matk: 100, matk_min: 100, matk_max: 100})
    defender = combatant(:player, @defender_id, %{mdef: 0, soft_mdef: 0})

    {:ok, %{damage: damage}} =
      MagicDamageCalculator.calculate_magic_damage(attacker, defender, element: element)

    damage
  end

  defp combatant(unit_type, unit_id, combat_stats) do
    %Combatant{
      unit_type: unit_type,
      unit_id: unit_id,
      base_stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      combat_stats: combat_stats,
      progression: %{base_level: 1, job_level: 1},
      element: {:neutral, 1},
      race: :formless,
      size: :medium,
      weapon: %{type: :fist, element: :neutral, size: :medium},
      attack_range: 1,
      attack_delay_ms: 1_000
    }
  end
end
