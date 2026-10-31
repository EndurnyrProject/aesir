defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ResistancePotionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  test "optional rates and flags retain their positions and unsupported forms reject the script" do
    prefix = "sc_start4 SC_ARMOR_ELEMENT_FIRE,1200000,-15,0,20,0"

    assert {:ok, rate} = Transpiler.transpile(prefix <> ",5000;")
    assert rate == "sc_start(ctx, :sc_armor_element_fire, 1200000, [-15, 0, 20, 0], 5000)"

    assert {:ok, flagged} = Transpiler.transpile(prefix <> ",10000,1;")
    assert flagged == "sc_start(ctx, :sc_armor_element_fire, 1200000, [-15, 0, 20, 0], 10000, 1)"

    for script <- [
          prefix <> ",10000,1,123;",
          "sc_start4 SC_ARMOR_ELEMENT_FIRE,1200000,-15,0,20;",
          "sc_start4 SC_ARMOR_ELEMENT_FIRE,1200000,-15,0,20,Hp;",
          "sc_start4 SC_NOT_A_STATUS,1200000,-15,0,20,0;",
          "sc_start2 SC_ARMOR_ELEMENT_FIRE,1200000,1,2;"
        ] do
      assert {:error, {:unsupported, _}} = Transpiler.transpile("heal 1,0; " <> script)
    end
  end

  test "four-value status commands preserve signed values and surrounding effects" do
    for {status, values} <- [
          {"FIRE", "-15,0,20,0"},
          {"WATER", "20,0,0,-15"},
          {"EARTH", "0,20,-15,0"},
          {"WIND", "0,-15,0,20"}
        ] do
      assert {:ok, source} =
               Transpiler.transpile(
                 "heal 1,0; sc_start4 SC_ARMOR_ELEMENT_#{status},1200000,#{values}; heal 0,2;"
               )

      assert source =~ "heal(ctx, hp: 1)"

      assert source =~
               "sc_start(ctx, :sc_armor_element_#{String.downcase(status)}, 1200000, [#{String.replace(values, ",", ", ")}])"

      assert source =~ "heal(ctx, sp: 2)"
      assert Code.string_to_quoted!(source)
    end
  end
end
