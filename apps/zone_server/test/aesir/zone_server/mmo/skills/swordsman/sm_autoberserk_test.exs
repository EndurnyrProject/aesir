defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmAutoberserkTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Swordsman.SmAutoberserk
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  setup :verify_on_exit!

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

  test "cast/4 keeps the cast when toggle_status refuses" do
    {:ok, definition} = Catalog.by_id(146)
    caster = %{character_id: 3000}

    expect(StatusInterpreter, :toggle_status, fn :player, 3000, :sc_autoberserk, [] ->
      {:error, :immune}
    end)

    assert {:ok, ^caster} = SmAutoberserk.cast(caster, :self, 1, definition)
  end

  test "requires the listed SP to cast but spends none" do
    {:ok, definition} = Catalog.by_id(146)

    caster =
      Aesir.ZoneServer.Unit.Player.PlayerState.new(%Aesir.Commons.Models.Character{
        id: 3000,
        account_id: 3000,
        name: "Swordsman",
        last_map: "prontera",
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 10,
        job_level: 10,
        class: 1
      })

    assert %Aesir.ZoneServer.Mmo.Skill.Cost{sp: 0, sp_requirement: 1} =
             SmAutoberserk.dynamic_cost(caster, :self, 1, definition)
  end
end
