defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ConsumableStatusBatchTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver
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

  test "card scroll syntax resolves only known icons and preserves rate and flags" do
    assert Resolver.resolve_status_icon("EFST_FOOD_BASICHIT") == {:ok, 248}
    assert Resolver.resolve_status_icon("EFST_ARMOR_PROPERTY") == {:ok, 302}

    for symbol <- ["EFST_NOT_A_REAL_ICON", "EFST_id", "food_basichit"] do
      assert Resolver.resolve_status_icon(symbol) == {:error, {:unknown_symbol, symbol}}
    end

    assert {:ok, "sc_start(ctx, :sc_itemscript, 180000, [4121, 248, 0, 0])"} =
             Transpiler.transpile("sc_start2 SC_ITEMSCRIPT,180000,4121,EFST_FOOD_BASICHIT;")

    assert {:ok, "sc_start(ctx, :sc_itemscript, 60000, [4047, 302, 0, 0], 7500, 1)"} =
             Transpiler.transpile(
               "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_ARMOR_PROPERTY,7500,1;"
             )

    for script <- [
          "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_NOT_A_REAL_ICON;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047,302,10000,0,42;",
          "sc_start2 SC_ITEMSCRIPT,60000,4047,302; unsupported_command;"
        ] do
      assert {:error, _} = Transpiler.transpile(script)
    end

    for script <- [
          "sc_start2 SC_ITEMSCRIPT,60000,4047,EFST_ARMOR_PROPERTY;",
          "sc_end SC_ITEMSCRIPT;",
          "itemheal 100,0;"
        ] do
      assert {:error, _} = Transpiler.transpile_equip(script, :equip)
    end
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
