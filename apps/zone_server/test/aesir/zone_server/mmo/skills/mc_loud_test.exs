defmodule Aesir.ZoneServer.Mmo.Skills.McLoudTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.McLoud
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  describe "metadata" do
    test "Catalog resolves id 155 and the atom name" do
      assert {:ok, McLoud} = Catalog.active_module_for(:mc_loud)
      assert {:ok, definition} = Catalog.by_id(155)
      assert definition.id == 155
      assert definition.name == :mc_loud
      assert definition.target_type == :self
      assert definition.max_level == 1
      assert definition.sp_cost == [8]
      assert definition.cast_time == [1000]
      assert definition.fixed_cast_time == [300]
      assert definition.after_cast_delay == [1000]
      assert definition.cooldown == [30_000]
    end
  end

  describe "cast/4" do
    test "applies SC_LOUD on first cast" do
      {:ok, definition} = Catalog.by_id(155)
      caster = %{character_id: 4000}

      expect(StatusInterpreter, :apply_status, fn :player, 4000, :sc_loud, duration: 300_000 ->
        :ok
      end)

      assert {:ok, ^caster} = McLoud.cast(caster, :self, 1, definition)
    end

    test "re-casting refreshes SC_LOUD instead of toggling it off" do
      {:ok, definition} = Catalog.by_id(155)
      caster = %{character_id: 4000}

      expect(StatusInterpreter, :apply_status, 2, fn :player, 4000, :sc_loud, duration: 300_000 ->
        :ok
      end)

      assert {:ok, ^caster} = McLoud.cast(caster, :self, 1, definition)
      assert {:ok, ^caster} = McLoud.cast(caster, :self, 1, definition)
    end

    test "propagates error from apply_status" do
      {:ok, definition} = Catalog.by_id(155)
      caster = %{character_id: 4000}

      expect(StatusInterpreter, :apply_status, fn :player, 4000, :sc_loud, duration: 300_000 ->
        {:error, :immune}
      end)

      assert {:error, :immune} = McLoud.cast(caster, :self, 1, definition)
    end
  end
end
