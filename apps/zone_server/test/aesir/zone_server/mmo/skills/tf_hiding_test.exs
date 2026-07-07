defmodule Aesir.ZoneServer.Mmo.Skills.TfHidingTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.TfHiding
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.by_id/1 resolves TF_HIDING" do
    assert {:ok, definition} = Catalog.by_id(51)
    assert definition.name == :tf_hiding
    assert definition.max_level == 10
    assert definition.target_type == :self
    assert definition.sp_cost == List.duplicate(10, 10)
  end

  test "cast/4 applies sc_hiding for 30000 * level ms on first cast" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, params ->
      assert params[:duration] == 30_000 * 5
      {:ok, :applied}
    end)

    assert {:ok, ^caster} = TfHiding.cast(caster, :self, 5, definition)
  end

  test "cast/4 removes sc_hiding on second cast" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, _params ->
      {:ok, :removed}
    end)

    assert {:ok, ^caster} = TfHiding.cast(caster, :self, 5, definition)
  end

  test "cast/4 propagates an error from toggle_status" do
    {:ok, definition} = Catalog.by_id(51)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_hiding, _params ->
      {:error, :immune}
    end)

    assert {:error, :immune} = TfHiding.cast(caster, :self, 5, definition)
  end
end
