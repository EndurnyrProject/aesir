defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSightTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Mage.MgSight
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  @caster %{character_id: 1000}

  describe "skill data" do
    test "mg_sight loads from the catalog as a self no-damage fire skill" do
      assert {:ok, definition} = Catalog.by_id(10)
      assert definition.name == :mg_sight
      assert definition.display_name == "Sight"
      assert definition.target_type == :self
      assert definition.damage_type == :no_damage
      assert definition.element == :fire
      assert definition.range == 0
      assert definition.splash_radius == 3
      assert definition.max_level == 1
      assert definition.sp_cost == [10]
    end

    test "is registered as an active skill" do
      assert {:ok, MgSight} = Catalog.active_module_for(:mg_sight)
    end
  end

  describe "cast/4" do
    test "applies sc_sight to the caster for 10 seconds" do
      expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_sight, params ->
        assert params[:duration] == 10_000
        assert params[:caster_id] == 1000
        :ok
      end)

      assert {:ok, @caster} = MgSight.cast(@caster, :self, 1, MgSight.definition())
    end

    test "propagates an apply failure" do
      stub(StatusInterpreter, :apply_status, fn :player, 1000, :sc_sight, _ ->
        {:error, :immune}
      end)

      assert {:error, :immune} = MgSight.cast(@caster, :self, 1, MgSight.definition())
    end
  end
end
