defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.HpSpPotionsTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler

  test "HP and SP potion scripts keep size, duration and the following percentage heal" do
    for {status, heals} <- [
          {"PROMOTE_HEALTH_RESERCH", [{1, 1, 0}, {2, 2, 0}, {3, 5, 0}]},
          {"ENERGY_DRINK_RESERCH", [{1, 0, 2}, {2, 0, 4}, {3, 0, 8}]}
        ],
        {size, hp, sp} <- heals do
      assert {:ok, source} =
               Transpiler.transpile(
                 "sc_start2 SC_#{status},500000,1,#{size}; percentheal #{hp},#{sp};"
               )

      assert source =~
               "sc_start(ctx, :sc_#{String.downcase(status)}, 500000, [1, #{size}, 0, 0])"

      assert source =~ "percent_heal(ctx, #{if hp == 0, do: "sp: #{sp}", else: "hp: #{hp}"})"
      assert Code.string_to_quoted!(source)
    end
  end

  test "rates and flags are preserved without admitting incomplete statuses or unit targets" do
    prefix = "sc_start2 SC_PROMOTE_HEALTH_RESERCH,500000,1,3"
    assert {:ok, source} = Transpiler.transpile(prefix <> ",5000,2;")
    assert source == "sc_start(ctx, :sc_promote_health_reserch, 500000, [1, 3, 0, 0], 5000, 2)"

    for script <- [
          prefix <> ",10000,2,123;",
          "sc_start2 SC_INCREASE_MAXSP,3600000,5,10; percentheal 0,10;",
          "sc_start2 SC_PROMOTE_HEALTH_RESERCH,500000,1,Hp;"
        ] do
      assert {:error, {:unsupported, _}} = Transpiler.transpile(script)
    end
  end
end
