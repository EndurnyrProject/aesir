defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ConsumableEquipmentQueriesTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "consumable equipment queries use right-hand view values and preserve the weapon gate" do
    script = """
    .@type = getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW);
    if (.@type == W_1HAXE || .@type == W_2HAXE || .@type == W_MACE) .@allowed = 1;
    """

    assert {:ok, source} = Transpiler.transpile(script)

    for {weapon, view, allowed} <- [
          {1301, 6, 1},
          {1351, 7, 1},
          {1501, 8, 1},
          {1201, 1, 0},
          {nil, -1, 0}
        ] do
      inventory = if weapon, do: %{0 => %InventoryItem{nameid: weapon, equip: 2}}, else: %{}

      ctx = %Ctx{
        char_id: 1,
        account_id: 1,
        connection_pid: self(),
        game_state: %PlayerState{inventory: inventory},
        source: {:item, 12220}
      }

      quoted =
        quote do
          import Dsl
          unquote(Code.string_to_quoted!(source))
        end

      {result, _binding} = Code.eval_quoted(quoted, ctx: ctx)
      assert result.vars.type == view
      assert Dsl.get_local(result, :allowed) == allowed
    end
  end

  test "the complete Adrenaline Scroll script retains its visual and direct status start" do
    script = """
    .@type = getiteminfo(getequipid(EQI_HAND_R),ITEMINFO_VIEW);
    if (.@type == W_1HAXE || .@type == W_2HAXE || .@type == W_MACE) {
      skilleffect "BS_ADRENALINE",0;
      sc_start SC_ADRENALINE,150000,5;
    }
    """

    assert {:ok, source} = Transpiler.transpile(script)
    assert source =~ "skilleffect(ctx, 111, 0)"
    assert source =~ "sc_start(ctx, :sc_adrenaline, 150000, 5)"
  end

  test "unknown slot, field and weapon constants reject the complete script" do
    for script <- [
          ".@type = getequipid(EQI_UNKNOWN);",
          ".@type = getiteminfo(1301,ITEMINFO_UNKNOWN);",
          "if (1 == W_UNKNOWN) .@allowed = 1;"
        ] do
      assert {:error, {:unsupported, {:unknown_const, _name}}} = Transpiler.transpile(script)
    end
  end
end
