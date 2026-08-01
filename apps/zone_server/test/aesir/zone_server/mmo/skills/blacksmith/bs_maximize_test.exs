defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMaximizeTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsMaximize
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves bs_maximize" do
    assert {:ok, BsMaximize} = Catalog.active_module_for(:bs_maximize)
  end

  test "cast/4 activates Maximize Power with its level-based tick interval" do
    {:ok, definition} = Catalog.by_id(114)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_maximizepower, tick: 5_000 ->
      {:ok, :applied}
    end)

    assert {:ok, ^caster} = BsMaximize.cast(caster, :self, 5, definition)
  end

  test "cast/4 removes Maximize Power when recast" do
    {:ok, definition} = Catalog.by_id(114)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_maximizepower, tick: 1_000 ->
      {:ok, :removed}
    end)

    assert {:ok, ^caster} = BsMaximize.cast(caster, :self, 1, definition)
  end

  test "cast/4 propagates errors from toggling Maximize Power" do
    {:ok, definition} = Catalog.by_id(114)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_maximizepower, tick: 1_000 ->
      {:error, :immune}
    end)

    assert {:error, :immune} = BsMaximize.cast(caster, :self, 1, definition)
  end
end
