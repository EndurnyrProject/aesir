defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgEnergycoatTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgEnergycoat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  describe "metadata" do
    test "classic spends the five seconds as an interruptible variable cast" do
      assert MgEnergycoat.definition(:renewal).cast_time == []
      assert MgEnergycoat.definition(:renewal).fixed_cast_time == [5_000]
      assert MgEnergycoat.definition(:pre_renewal).cast_time == [5_000]
    end
  end

  describe "absorbed damage kinds" do
    test "renewal soaks both weapon and magic hits" do
      assert EnergyCoat.absorbs?(:renewal, :physical)
      assert EnergyCoat.absorbs?(:renewal, :magic)
    end

    test "classic soaks weapon hits only" do
      assert EnergyCoat.absorbs?(:pre_renewal, :physical)
      refute EnergyCoat.absorbs?(:pre_renewal, :magic)
    end
  end

  describe "cast/4" do
    test "applies SC_ENERGYCOAT on first cast" do
      {:ok, definition} = Catalog.by_id(157)
      caster = %{character_id: 3000}

      expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_energycoat, [] ->
        :ok
      end)

      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
    end

    test "re-casting refreshes SC_ENERGYCOAT instead of toggling it off" do
      {:ok, definition} = Catalog.by_id(157)
      caster = %{character_id: 3000}

      expect(StatusInterpreter, :apply_status, 2, fn :player, 3000, :sc_energycoat, [] ->
        :ok
      end)

      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
    end

    test "keeps the cast when the status is refused" do
      {:ok, definition} = Catalog.by_id(157)
      caster = %{character_id: 3000}

      expect(StatusInterpreter, :apply_status, fn :player, 3000, :sc_energycoat, [] ->
        {:error, :immune}
      end)

      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
    end
  end
end
