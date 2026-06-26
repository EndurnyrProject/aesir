defmodule Aesir.ZoneServer.Mmo.Skills.AlAngelusTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.AlAngelus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

  test "Catalog.by_id/1 resolves al_angelus" do
    assert {:ok, definition} = Catalog.by_id(33)
    assert definition.name == :al_angelus
  end

  test "Catalog.by_name/1 resolves al_angelus" do
    assert {:ok, definition} = Catalog.by_name(:al_angelus)
    assert definition.id == 33
  end

  test "definition cooldown is 30_000ms at every level" do
    assert {:ok, definition} = Catalog.by_id(33)
    assert Enum.all?(definition.cooldown, &(&1 == 30_000))
  end

  test "cast/4 applies SC_ANGELUS to the caster at level 1" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, params ->
      assert params[:val1] == 1
      assert params[:val2] == 5
      assert params[:caster_id] == 500
      assert params[:duration] == 30_000
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 1, definition)
  end

  test "cast/4 applies SC_ANGELUS to the caster at level 10" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, params ->
      assert params[:val1] == 10
      assert params[:val2] == 50
      assert params[:caster_id] == 500
      assert params[:duration] == 300_000
      :ok
    end)

    assert {:ok, ^caster} = AlAngelus.cast(caster, :self, 10, definition)
  end

  test "cast/4 propagates error from StatusInterpreter" do
    {:ok, definition} = Catalog.by_id(33)
    caster = %{character_id: 500}

    expect(StatusInterpreter, :apply_status, fn :player, 500, :sc_angelus, _params ->
      {:error, :prevented}
    end)

    assert {:error, :prevented} = AlAngelus.cast(caster, :self, 5, definition)
  end
end
