defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndureTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmEndure
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves sm_endure" do
    assert {:ok, SmEndure} = Catalog.active_module_for(:sm_endure)
  end

  test "cast/4 applies SC_ENDURE with val1=level and correct duration" do
    {:ok, definition} = Catalog.by_id(8)
    caster = %{character_id: 2000}

    expect(StatusInterpreter, :apply_status, fn :player, 2000, :sc_endure, params ->
      assert params[:val1] == 3
      assert params[:caster_id] == 2000
      assert params[:duration] == Enum.at(definition.duration, 2)
      :ok
    end)

    assert {:ok, ^caster} = SmEndure.cast(caster, :self, 3, definition)
  end
end
