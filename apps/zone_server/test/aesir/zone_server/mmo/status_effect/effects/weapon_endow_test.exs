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
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
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

    stub(ElementModifiers, :adjust_damage, fn damage, adjustment ->
      send(self(), {:attack_element, adjustment.attack_element})
      call_original(ElementModifiers, :adjust_damage, [damage, adjustment])
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

  # The mutually exclusive weapon endows, with the element each must hand the
  # element table. They carry a fixed element and ignore `val1`.
  @endows [
    {:sc_aspersio, :holy},
    {:sc_encpoison, :poison},
    {:sc_fireweapon, :fire},
    {:sc_waterweapon, :water},
    {:sc_windweapon, :wind},
    {:sc_earthweapon, :earth}
  ]

  describe "a single endow" do
    # Weapon Enchant reads its element from `val1` (rAthena element id 3 => fire).
    for {status_id, element} <- [{:sc_enchantarms, :fire} | @endows] do
      test "#{status_id} endows the weapon with the #{element} element" do
        :ok =
          StatusStorage.apply_status(:player, @attacker_id, unquote(status_id),
            duration: 30_000,
            val1: 3
          )

        attack_undead()

        assert_received {:attack_element, unquote(element)}
      end
    end
  end

  describe "RemoveOnUnequipWeapon flag" do
    for status_id <- [
          :sc_fireweapon,
          :sc_waterweapon,
          :sc_windweapon,
          :sc_earthweapon,
          :sc_enchantarms
        ] do
      test "#{status_id} carries :remove_on_unequip_weapon" do
        assert :remove_on_unequip_weapon in Registry.get_definition(unquote(status_id)).flags
      end
    end

    test "sc_watk_element does NOT carry :remove_on_unequip_weapon" do
      refute :remove_on_unequip_weapon in Registry.get_definition(:sc_watk_element).flags
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
    # `end_on_start` only fires for the status being applied, so exclusion has
    # to be declared in both directions. Every ordered pair is exercised: a
    # missing direction leaves both endows live and the summed atoms raise.
    for {first, _} <- @endows, {second, expected} <- @endows, first != second do
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

  describe "Weapon Enchant" do
    # It neither ends nor is ended by the elemental Sage endows and outranks
    # them for the attack element, whichever arrived first.
    for other <- [:sc_fireweapon, :sc_waterweapon, :sc_windweapon, :sc_earthweapon],
        order <- [:before, :after] do
      test "outranks #{other} applied #{order} it" do
        statuses =
          if unquote(order) == :before,
            do: [{unquote(other), 0}, {:sc_enchantarms, 9}],
            else: [{:sc_enchantarms, 9}, {unquote(other), 0}]

        for {status_id, val1} <- statuses do
          :ok =
            Interpreter.apply_status(:player, @attacker_id, status_id,
              duration: 30_000,
              val1: val1
            )
        end

        attack_undead()

        assert_received {:attack_element, :undead}
        assert StatusStorage.has_status?(:player, @attacker_id, unquote(other))
      end
    end

    test "ends Aspersio and is ended by it" do
      apply_in_order([:sc_aspersio, :sc_enchantarms])
      refute StatusStorage.has_status?(:player, @attacker_id, :sc_aspersio)

      apply_in_order([:sc_aspersio])
      refute StatusStorage.has_status?(:player, @attacker_id, :sc_enchantarms)
    end

    @tag game_mode: :pre_renewal
    test "classic Enchant Poison ends it" do
      apply_in_order([:sc_enchantarms, :sc_encpoison])

      refute StatusStorage.has_status?(:player, @attacker_id, :sc_enchantarms)
    end

    @tag game_mode: :renewal
    test "renewal Enchant Poison coexists with it and loses the attack element" do
      apply_in_order([:sc_enchantarms, :sc_encpoison])

      attack_undead()

      assert_received {:attack_element, :undead}
      assert StatusStorage.has_status?(:player, @attacker_id, :sc_encpoison)
    end

    test "a later Weapon Enchant replaces an earlier one" do
      :ok =
        Interpreter.apply_status(:player, @attacker_id, :sc_enchantarms,
          duration: 30_000,
          val1: 9
        )

      :ok =
        Interpreter.apply_status(:player, @attacker_id, :sc_enchantarms,
          duration: 30_000,
          val1: 1
        )

      attack_undead()

      assert_received {:attack_element, :water}
    end
  end

  defp apply_in_order(status_ids) do
    for status_id <- status_ids do
      :ok = Interpreter.apply_status(:player, @attacker_id, status_id, duration: 30_000, val1: 9)
    end
  end
end
