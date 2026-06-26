defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PneumaTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Pneuma
  alias Aesir.ZoneServer.Mmo.StatusEntry

  @target {:player, 1000}

  defp instance, do: %StatusEntry{type: :sc_pneuma, state: %{}}

  describe "metadata" do
    test "is a buff with id :sc_pneuma" do
      assert :sc_pneuma = Pneuma.id()
      assert %{properties: [:buff]} = Pneuma.metadata()
    end
  end

  describe "absorb_damage/4 - ranged physical" do
    test "blocks fully, returning zero damage" do
      entry = instance()
      hit = %{damage: 800, is_short: false, dmg_type: :physical, element: :neutral}

      assert {:ok, 0, ^entry} = Pneuma.absorb_damage(@target, entry, hit, %{})
    end
  end

  describe "absorb_damage/4 - pass-through" do
    test "melee physical hits pass through unmodified" do
      entry = instance()
      hit = %{damage: 500, is_short: true, dmg_type: :physical, element: :neutral}

      assert {:ok, 500, ^entry} = Pneuma.absorb_damage(@target, entry, hit, %{})
    end

    test "magic hits pass through unmodified" do
      entry = instance()
      hit = %{damage: 700, is_short: false, dmg_type: :magic, element: :holy}

      assert {:ok, 700, ^entry} = Pneuma.absorb_damage(@target, entry, hit, %{})
    end
  end
end
