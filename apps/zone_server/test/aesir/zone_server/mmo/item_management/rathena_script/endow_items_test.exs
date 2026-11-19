defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EndowItemsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.EquipScript
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  test "a nested wind endow remains a timed weapon-hit autobonus" do
    script = ~S[autobonus "{ sc_start SC_WINDWEAPON, 180000, 1; }",3,180000,BF_WEAPON;]

    assert {:ok, program} = Transpiler.transpile_equip(script)

    assert [%{rate: 3, duration_ms: 180_000, primary: primary}] =
             EquipScript.evaluate(program, %{}).autobonuses

    assert EquipScript.evaluate(primary, %{}).effects ==
             [{:status_start, :sc_windweapon, 180_000, 1}]
  end
end
