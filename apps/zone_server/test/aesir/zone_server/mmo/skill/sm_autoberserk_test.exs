defmodule Aesir.ZoneServer.Mmo.Skill.SmAutoberserkTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Behaviors
  alias Aesir.ZoneServer.Mmo.Skill.Behaviors.SmAutoberserk
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Behaviors.module_for/1 resolves sm_autoberserk" do
    assert {:ok, SmAutoberserk} = Behaviors.module_for(:sm_autoberserk)
  end

  test "cast/4 applies SC_AUTOBERSERK on first cast" do
    {:ok, definition} = Catalog.by_id(146)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_autoberserk, [] ->
      {:ok, :applied}
    end)

    assert {:ok, ^caster} = SmAutoberserk.cast(caster, :self, 1, definition)
  end

  test "cast/4 removes SC_AUTOBERSERK on second cast" do
    {:ok, definition} = Catalog.by_id(146)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_autoberserk, [] ->
      {:ok, :removed}
    end)

    assert {:ok, ^caster} = SmAutoberserk.cast(caster, :self, 1, definition)
  end

  test "cast/4 propagates error from toggle_status" do
    {:ok, definition} = Catalog.by_id(146)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_autoberserk, [] ->
      {:error, :immune}
    end)

    assert {:error, :immune} = SmAutoberserk.cast(caster, :self, 1, definition)
  end
end
