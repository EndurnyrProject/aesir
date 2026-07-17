defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.WeaponEndowTest do
  @moduledoc """
  Weapon endow statuses drive the attack element the damage calculator uses.

  These exercise the real status storage and modifier aggregation, so an endow
  whose `modifiers/2` returns a key the combat engine does not read attacks
  with the weapon's own element instead of the endowed one.

  Base attack carries random variance, so the endow is asserted through the
  element handed to the element table rather than by comparing damage numbers.
  """

  use ExUnit.Case, async: true
  use Mimic

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Mmo.Combat.CriticalHits
  alias Aesir.ZoneServer.Mmo.Combat.DamageCalculator
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @attacker_id 1001

  setup :set_mimic_from_context
  setup :verify_on_exit!

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})

    Mimic.copy(CriticalHits)
    Mimic.copy(ElementModifiers)
    Mimic.copy(UnitRegistry)

    stub(CriticalHits, :calculate_critical_hit, fn _, damage ->
      %{damage: damage, is_critical: false}
    end)

    stub(ElementModifiers, :get_modifier, fn attack_element, defense_element, defense_level ->
      send(self(), {:attack_element, attack_element})

      call_original(ElementModifiers, :get_modifier, [
        attack_element,
        defense_element,
        defense_level
      ])
    end)

    # The endows read no context; the registry only has to answer the
    # ContextBuilder lookup that modifier aggregation performs.
    stub(UnitRegistry, :get_unit_info, fn _, _ -> {:ok, %{stats: %{}}} end)

    :ok
  end

  defp attack_undead do
    attacker = CombatTestHelper.create_player_combatant(unit_id: @attacker_id, str: 50)
    defender = CombatTestHelper.create_mob_combatant(element: {:undead, 1})

    assert {:ok, _} = DamageCalculator.calculate_damage(attacker, defender)
  end

  describe "sc_aspersio" do
    test "endows the weapon with the holy element" do
      :ok = StatusStorage.apply_status(:player, @attacker_id, :sc_aspersio, duration: 30_000)

      attack_undead()

      assert_received {:attack_element, :holy}
    end
  end

  describe "sc_encpoison" do
    test "endows the weapon with the poison element" do
      :ok = StatusStorage.apply_status(:player, @attacker_id, :sc_encpoison, duration: 30_000)

      attack_undead()

      assert_received {:attack_element, :poison}
    end
  end

  describe "without an endow" do
    test "attacks with the weapon's own element" do
      attack_undead()

      assert_received {:attack_element, :neutral}
    end
  end

  describe "endows are mutually exclusive" do
    # Every endow contributes the same `attack_element` modifier, and modifier
    # aggregation sums colliding keys. Two live endows would therefore add two
    # atoms and crash the carrier's session, so each endow has to displace the
    # others whichever order they arrive in.
    endows = [
      {:sc_aspersio, :holy},
      {:sc_encpoison, :poison},
      {:sc_watk_element, :fire}
    ]

    for {first, _} <- endows, {second, expected} <- endows, first != second do
      test "#{second} replaces #{first}" do
        :ok =
          Interpreter.apply_status(:player, @attacker_id, unquote(first),
            duration: 30_000,
            val1: 3
          )

        :ok =
          Interpreter.apply_status(:player, @attacker_id, unquote(second),
            duration: 30_000,
            val1: 3
          )

        attack_undead()

        assert_received {:attack_element, unquote(expected)}
      end
    end
  end
end
