defmodule Aesir.ZoneServer.Mmo.Skills.NvTrickdeadTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.NvTrickdead
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.active_module_for/1 resolves nv_trickdead" do
    assert {:ok, NvTrickdead} = Catalog.active_module_for(:nv_trickdead)
  end

  test "cast/4 applies SC_TRICKDEAD on first cast" do
    {:ok, definition} = Catalog.by_id(143)
    caster = %{character_id: 5000}

    expect(StatusInterpreter, :toggle_status, fn :player, 5000, :sc_trickdead, [] ->
      {:ok, :applied}
    end)

    assert {:ok, ^caster} = NvTrickdead.cast(caster, :self, 1, definition)
  end

  test "cast/4 removes SC_TRICKDEAD on second cast" do
    {:ok, definition} = Catalog.by_id(143)
    caster = %{character_id: 5000}

    expect(StatusInterpreter, :toggle_status, fn :player, 5000, :sc_trickdead, [] ->
      {:ok, :removed}
    end)

    assert {:ok, ^caster} = NvTrickdead.cast(caster, :self, 1, definition)
  end

  test "cast/4 propagates error from toggle_status" do
    {:ok, definition} = Catalog.by_id(143)
    caster = %{character_id: 5000}

    expect(StatusInterpreter, :toggle_status, fn :player, 5000, :sc_trickdead, [] ->
      {:error, :immune}
    end)

    assert {:error, :immune} = NvTrickdead.cast(caster, :self, 1, definition)
  end
end
