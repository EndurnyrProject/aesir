defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfHidingTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Thief.TfHiding
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  setup :verify_on_exit!

  test "cast/4 applies sc_hiding for 30000 * level ms on first cast" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %PlayerState{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, params ->
      assert params[:duration] == 30_000 * 5
      {:ok, :applied}
    end)

    assert {:ok, ^caster} = TfHiding.cast(caster, :self, 5, definition)
  end

  test "cast/4 removes sc_hiding on second cast" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %PlayerState{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, _params ->
      {:ok, :removed}
    end)

    assert {:ok, ^caster} = TfHiding.cast(caster, :self, 5, definition)
  end

  test "cast/4 keeps the cast when toggle_status refuses" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %PlayerState{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, _params ->
      {:error, :immune}
    end)

    assert {:ok, ^caster} = TfHiding.cast(caster, :self, 5, definition)
  end
end
