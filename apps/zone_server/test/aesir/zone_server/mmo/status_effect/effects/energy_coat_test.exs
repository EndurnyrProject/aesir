defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoatTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusEntry

  setup :verify_on_exit!

  @target {:player, 1000}

  defp entry, do: %StatusEntry{type: :sc_energycoat, state: %{}}

  # SP% = 100 * sp / max_sp. per = clamp(div(SP%, 20), 0, 4).
  defp context(sp, max_sp), do: %{target: %{sp: sp, max_sp: max_sp}}

  describe "metadata" do
    test "is a 5-minute buff mapped to client status id 49" do
      assert :sc_energycoat = EnergyCoat.id()
      assert %{properties: [:buff], duration: 300_000} = EnergyCoat.metadata()
    end
  end

  describe "absorb_damage/4 - damage reduction" do
    test "at full SP (per = 4) reduces a physical hit by 30%" do
      stub(Helpers, :consume_sp, fn _target, _amount -> :ok end)
      hit = %{damage: 1_000, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:ok, 700, %StatusEntry{}} =
               EnergyCoat.absorb_damage(@target, entry(), hit, context(200, 200))
    end

    test "at half SP (per = 2) reduces a magic hit by 18%" do
      stub(Helpers, :consume_sp, fn _target, _amount -> :ok end)
      hit = %{damage: 1_000, is_short: false, dmg_type: :magic, element: :fire}

      assert {:ok, 820, %StatusEntry{}} =
               EnergyCoat.absorb_damage(@target, entry(), hit, context(100, 200))
    end

    test "at no SP (per = 0) still reduces by the base 6%" do
      stub(Helpers, :consume_sp, fn _target, _amount -> :ok end)
      hit = %{damage: 1_000, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:ok, 940, %StatusEntry{}} =
               EnergyCoat.absorb_damage(@target, entry(), hit, context(20, 200))
    end
  end

  describe "absorb_damage/4 - SP drain" do
    test "drains (10 + 5*per) * max_sp / 1000 SP per hit" do
      expect(Helpers, :consume_sp, fn @target, 6 -> :ok end)
      hit = %{damage: 1_000, is_short: true, dmg_type: :physical, element: :neutral}

      EnergyCoat.absorb_damage(@target, entry(), hit, context(200, 200))
    end
  end

  describe "absorb_damage/4 - removal" do
    test "removes when current SP cannot pay the drain" do
      reject(&Helpers.consume_sp/2)
      hit = %{damage: 1_000, is_short: true, dmg_type: :physical, element: :neutral}

      assert :remove = EnergyCoat.absorb_damage(@target, entry(), hit, context(1, 200))
    end
  end

  describe "absorb_damage/4 - pass-through" do
    test "non weapon/magic hits pass through unmodified and do not drain" do
      reject(&Helpers.consume_sp/2)
      e = entry()
      hit = %{damage: 500, is_short: true, dmg_type: :misc, element: :neutral}

      assert {:ok, 500, ^e} = EnergyCoat.absorb_damage(@target, e, hit, context(200, 200))
    end
  end
end
