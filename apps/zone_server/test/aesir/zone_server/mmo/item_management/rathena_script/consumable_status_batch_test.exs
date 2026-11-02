defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ConsumableStatusBatchTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.StatusEffect.CalcFlags

  test "two-value consumables retain recovery and hit values before the following heal" do
    for status <- ["INCREASE_MAXHP", "INCREASE_MAXSP", "ACARAJE"] do
      assert {:ok, source} =
               Transpiler.transpile("sc_start2 SC_#{status},3600000,5,10; percentheal 0,10;")

      assert source =~ "sc_start(ctx, :sc_#{String.downcase(status)}, 3600000, [5, 10, 0, 0])"
      assert source =~ "percent_heal(ctx, sp: 10)"
    end

    assert {:ok, "sc_start(ctx, :sc_itemscript, 180000, [4121, 0, 0, 0])"} =
             Transpiler.transpile("sc_start2 SC_ITEMSCRIPT,180000,4121,0;")
  end

  test "elemental change resolves its element constant without losing the fixed-level marker" do
    for {element, id} <- [{"Holy", 6}, {"Dark", 7}] do
      assert {:ok, source} =
               Transpiler.transpile(
                 "specialeffect2 EF_BENEDICTIO; sc_start4 SC_ELEMENTALCHANGE,1800000,1,Ele_#{element},1,0;"
               )

      assert source =~ "specialeffect2(ctx, :benedictio)"
      assert source =~ "sc_start(ctx, :sc_elementalchange, 1800000, [1, #{id}, 1, 0])"
    end
  end

  test "Renewal potion scripts preserve the signed percentage and recovery interval" do
    for {status, val1, val2} <- [
          {"SC_S_LIFEPOTION", -5, 5},
          {"SC_L_LIFEPOTION", -7, 4},
          {"SC_VITATA_500", 20, 5}
        ] do
      assert {:ok, source} =
               Transpiler.transpile("sc_start2 #{status},600000,#{val1},#{val2};")

      assert source ==
               "sc_start(ctx, :#{String.downcase(status)}, 600000, [#{val1}, #{val2}, 0, 0])"
    end
  end

  test "script-backed statuses force full recalculation even without explicit flags" do
    rows = [
      %{"id" => "sc_scripted", "flags" => [], "scripted" => true, "available" => true},
      %{"id" => "sc_plain", "flags" => ["MaxHp"], "scripted" => false, "available" => true}
    ]

    assert CalcFlags.build_index!(rows, []) == %{
             "sc_scripted" => ["All"],
             "sc_plain" => ["MaxHp"]
           }
  end
end
