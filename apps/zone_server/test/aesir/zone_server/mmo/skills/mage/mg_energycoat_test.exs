defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgEnergycoatTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgEnergycoat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnergyCoat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  describe "metadata" do
    test "Catalog resolves id 157 and the atom name" do
      assert {:ok, MgEnergycoat} = Catalog.active_module_for(:mg_energycoat)
      assert {:ok, definition} = Catalog.by_id(157)
      assert definition.id == 157
      assert definition.name == :mg_energycoat
      assert definition.target_type == :self
      assert definition.max_level == 1
      assert definition.sp_cost == [30]
      assert definition.fixed_cast_time == [5_000]
    end

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

      expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_energycoat, [] ->
        {:ok, :applied}
      end)

      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
    end

    test "removes SC_ENERGYCOAT on second cast" do
      {:ok, definition} = Catalog.by_id(157)
      caster = %{character_id: 3000}

      expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_energycoat, [] ->
        {:ok, :removed}
      end)

      assert {:ok, ^caster} = MgEnergycoat.cast(caster, :self, 1, definition)
    end

    test "propagates error from toggle_status" do
      {:ok, definition} = Catalog.by_id(157)
      caster = %{character_id: 3000}

      expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_energycoat, [] ->
        {:error, :immune}
      end)

      assert {:error, :immune} = MgEnergycoat.cast(caster, :self, 1, definition)
    end
  end
end
