defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagiTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves al_incagi" do
    assert {:ok, AlIncagi} = Catalog.active_module_for(:al_incagi)
  end

  test "cast/4 applies SC_INCREASEAGI with val1=level, val2=2+level" do
    {:ok, definition} = Catalog.by_id(29)
    caster = %{character_id: 1000}

    expect(StatusInterpreter, :apply_status, fn :player, 1000, :sc_increaseagi, params ->
      assert params[:val1] == 5
      assert params[:val2] == 7
      assert params[:caster_id] == 1000
      assert params[:duration] == Enum.at(definition.duration, 4)
      :ok
    end)

    assert {:ok, ^caster} = AlIncagi.cast(caster, :self, 5, definition)
  end
end
