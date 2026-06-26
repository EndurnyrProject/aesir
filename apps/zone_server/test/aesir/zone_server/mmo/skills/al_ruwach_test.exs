defmodule Aesir.ZoneServer.Mmo.Skills.AlRuwachTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlRuwach
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.by_id/1 resolves al_ruwach" do
    assert {:ok, definition} = Catalog.by_id(24)
    assert definition.name == :al_ruwach
  end

  test "Catalog.by_name/1 resolves al_ruwach" do
    assert {:ok, definition} = Catalog.by_name(:al_ruwach)
    assert definition.id == 24
  end

  test "cast/4 applies SC_RUWACH to the caster" do
    {:ok, definition} = Catalog.by_id(24)
    caster = %{character_id: 100}

    expect(StatusInterpreter, :apply_status, fn :player, 100, :sc_ruwach, params ->
      assert params[:val1] == 1
      assert params[:caster_id] == 100
      refute Keyword.has_key?(params, :duration)
      :ok
    end)

    assert {:ok, ^caster} = AlRuwach.cast(caster, :self, 1, definition)
  end

  test "cast/4 propagates error from StatusInterpreter" do
    {:ok, definition} = Catalog.by_id(24)
    caster = %{character_id: 100}

    expect(StatusInterpreter, :apply_status, fn :player, 100, :sc_ruwach, _params ->
      {:error, :prevented}
    end)

    assert {:error, :prevented} = AlRuwach.cast(caster, :self, 1, definition)
  end
end
