defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlRuwachTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlRuwach
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

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
