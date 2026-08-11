defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CodegenTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Codegen
  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  defp compile(script) do
    with {:ok, ast} <- Parser.parse_body(script) do
      Codegen.generate(ast)
    end
  end

  test "homevolution emits the generic zero-argument DSL call" do
    assert {:ok, "homevolution(ctx)"} = compile("homevolution;")
  end

  describe "generate/1 healing commands" do
    test "itemheal omits sp when zero" do
      assert {:ok, "heal(ctx, hp: 45)"} = compile("itemheal 45,0;")
    end

    test "itemheal omits hp when zero" do
      assert {:ok, "heal(ctx, sp: 30)"} = compile("itemheal 0,30;")
    end

    test "itemheal keeps both hp and sp" do
      assert {:ok, "heal(ctx, hp: 45, sp: 30)"} = compile("itemheal 45,30;")
    end

    test "itemheal with rand(a,b) emits a range" do
      assert {:ok, "heal(ctx, hp: 45..65)"} = compile("itemheal rand(45,65),0;")
    end

    test "itemheal with rand(n) emits a 0-based range" do
      assert {:ok, "heal(ctx, hp: 0..99)"} = compile("itemheal rand(100),0;")
    end

    test "itemheal with a negative amount passes it through" do
      assert {:ok, "heal(ctx, hp: -100)"} = compile("itemheal -100,0;")
    end

    test "percentheal maps to percent_heal" do
      assert {:ok, "percent_heal(ctx, hp: 50)"} = compile("percentheal 50,0;")
    end

    test "heal maps to heal" do
      assert {:ok, "heal(ctx, hp: 100)"} = compile("heal 100,0;")
    end
  end

  describe "generate/1 status commands" do
    test "sc_start resolves the status constant" do
      assert {:ok, "sc_start(ctx, :sc_blessing, 60000, 10)"} =
               compile("sc_start SC_BLESSING,60000,10;")
    end

    test "sc_start with a hex tick literal renders its decimal value" do
      assert {:ok, "sc_start(ctx, :sc_blessing, 60000, 10)"} =
               compile("sc_start SC_BLESSING,0xEA60,10;")
    end

    test "sc_start with rate wraps the call in a random-roll guard" do
      assert {:ok,
              "if(Enum.random(1..10_000) <= 2500, do: sc_start(ctx, :sc_freeze, 10000, 0), else: ctx)"} =
               compile("sc_start SC_FREEZE,10000,0,2500,0;")
    end

    test "sc_start with a 10000 rate collapses to the plain call" do
      assert {:ok, "sc_start(ctx, :sc_stun, 3000, 0)"} =
               compile("sc_start SC_STUN,3000,0,10000,0;")
    end

    test "sc_start GID-targeted six-arg form is unsupported" do
      assert {:error, {:unsupported, _}} = compile("sc_start SC_BLIND,2000,0,1500,0,12345;")
    end

    test "sc_end resolves the status constant" do
      assert {:ok, "sc_end(ctx, :sc_blessing)"} = compile("sc_end SC_BLESSING;")
    end

    test "unknown status is unsupported" do
      assert {:error, {:unsupported, _}} = compile("sc_start SC_NOPE,1,1;")
    end

    test "char var increment emits a set_char_var/get_char_var round-trip" do
      assert {:ok, "set_char_var(ctx, :RouletteGold, get_char_var(ctx, :RouletteGold, 0) + 1)"} =
               compile("RouletteGold++;")
    end

    test "char var decrement emits a minus round-trip" do
      assert {:ok, "set_char_var(ctx, :RouletteGold, get_char_var(ctx, :RouletteGold, 0) - 1)"} =
               compile("RouletteGold--;")
    end

    test "specialeffect2 resolves an EF_ constant to its effect atom" do
      assert {:ok, "specialeffect2(ctx, :heal2)"} = compile("specialeffect2 EF_HEAL2;")
    end

    test "unknown special effect is unsupported" do
      assert {:error, {:unsupported, {:unknown_symbol, "EF_NOPE"}}} =
               compile("specialeffect2 EF_NOPE;")
    end
  end

  describe "generate/1 control flow" do
    test "if/else emits parseable Elixir" do
      assert {:ok, source} =
               compile("if (BaseLevel > 70) itemheal 100,0; else itemheal 50,0;")

      assert Code.string_to_quoted!(source)
    end

    test "if without else returns ctx in the empty branch" do
      assert {:ok, source} = compile("if (Sex == 1) itemheal 10,0;")
      assert Code.string_to_quoted!(source)
      assert source =~ "else\n  ctx\nend"
    end

    test "a block-bodied if flattens into the branch statement list" do
      assert {:ok, source} =
               compile("if (BaseLevel > 70) { itemheal 100,0; itemheal 0,30; }")

      assert Code.string_to_quoted!(source)
      assert source =~ "ctx = heal(ctx, hp: 100)"
      assert source =~ "ctx = heal(ctx, sp: 30)"
    end

    test "class branch resolves a Job_ constant" do
      assert {:ok, source} =
               compile("if (Class == Job_Knight) sc_start SC_BLESSING,60000,10;")

      assert Code.string_to_quoted!(source)
      assert source =~ ":knight"
    end
  end

  describe "generate/1 multi-statement threading" do
    test "sequential statements thread ctx through a rebinding block" do
      assert {:ok, source} = compile("itemheal 45,0; sc_start SC_BLESSING,60000,10;")

      assert Code.string_to_quoted!(source)
      assert source =~ "ctx = heal(ctx, hp: 45)"
      assert source =~ "ctx = sc_start(ctx, :sc_blessing, 60000, 10)"
    end
  end

  describe "generate/1 item and skill commands" do
    setup do
      potion = %ItemDefinition{
        id: 501,
        aegis_name: "Red_Potion",
        name: "Red Potion",
        type: :healing
      }

      index = %{all: [potion], by_id: %{501 => potion}, by_aegis: %{"Red_Potion" => potion}}
      :persistent_term.put(Items, index)
      on_exit(fn -> :persistent_term.erase(Items) end)
      :ok
    end

    test "getitem maps to give_item with a resolved id" do
      assert {:ok, "give_item(ctx, 501, 1)"} = compile("getitem Red_Potion,1;")
    end

    test "item-group commands resolve keys and default the optional subgroup" do
      assert {:ok, "get_group_item(ctx, :bluebox)"} = compile("getgroupitem IG_BlueBox;")

      assert {:ok, "get_rand_group_item(ctx, :ore, 2, 0)"} =
               compile("getrandgroupitem IG_Ore,2;")

      assert {:ok, "get_rand_group_item(ctx, :ore, 2, 3)"} =
               compile("getrandgroupitem IG_Ore,2,3;")
    end

    test "groupranditem works in getitem expression position" do
      assert {:ok, "give_item(ctx, group_rand_item(ctx, :ore, 0), 1)"} =
               compile("getitem groupranditem(IG_Ore),1;")

      assert {:ok, "give_item(ctx, group_rand_item(ctx, :ore, 2), 1)"} =
               compile("getitem groupranditem(IG_Ore,2),1;")
    end

    test "an unknown item-group constant follows the unsupported symbol path" do
      assert {:error, {:unsupported, {:unknown_symbol, "IG_Not_A_Group"}}} =
               compile("getgroupitem IG_Not_A_Group;")
    end

    test "delitem resolves a numeric id" do
      assert {:ok, "delitem(ctx, 501, 2)"} = compile("delitem 501,2;")
    end

    test "warp emits literal coords" do
      assert {:ok, "warp(ctx, \"prontera\", 155, 183)"} =
               compile("warp \"prontera\",155,183;")
    end

    test "warp \"Random\" emits the random-cell form (fly wing)" do
      assert {:ok, "warp(ctx, :random)"} = compile("warp \"Random\",0,0;")
    end

    test "warp \"SavePoint\" emits the save-point form (butterfly wing)" do
      assert {:ok, "warp(ctx, :save_point)"} = compile("warp \"SavePoint\",0,0;")
    end
  end

  describe "generate/1 announce broadcasts" do
    test "announce with a single bc_ flag resolves it to its integer value" do
      assert {:ok, "announce(ctx, \"hi\", 3)"} = compile(~s(announce "hi",bc_self;))
    end

    test "announce folds a bitwise flag union at transpile time" do
      assert {:ok, "announce(ctx, \"hi\", 16)"} = compile(~s(announce "hi",bc_all|bc_blue;))
    end

    test "broadcast maps to the broadcast DSL call" do
      assert {:ok, "broadcast(ctx, \"hi\", 0)"} = compile(~s(broadcast "hi",bc_all;))
    end

    test "mapannounce keeps the map and text before the flag" do
      assert {:ok, "mapannounce(ctx, \"prontera\", \"hi\", 1)"} =
               compile(~s(mapannounce "prontera","hi",bc_map;))
    end

    test "areaannounce keeps the rectangle, text and flag" do
      assert {:ok, "areaannounce(ctx, \"prontera\", 10, 10, 20, 20, \"hi\", 2)"} =
               compile(~s(areaannounce "prontera",10,10,20,20,"hi",bc_area;))
    end

    test "announce passes a decimal color through after the flag" do
      assert {:ok, "announce(ctx, \"hi\", 0, 16711680)"} =
               compile(~s(announce "hi",bc_all,16711680;))
    end

    test "announce drops the trailing font tail beyond the color" do
      assert {:ok, "announce(ctx, \"hi\", 0, 16711680)"} =
               compile(~s(announce "hi",bc_all,16711680,400,12,0,0;))
    end

    test "an unresolvable flag const is unsupported, not a raise" do
      assert {:error, {:unsupported, _}} = compile(~s(announce "hi",bc_nope;))
    end
  end

  describe "generate/1 unsupported" do
    test "an unknown command is unsupported with its name" do
      assert {:error, {:unsupported, "produce"}} = compile("produce 999,1;")
    end

    test "an NPC-only statement is unsupported, not a raise" do
      assert {:error, {:unsupported, {:statement, _}}} =
               compile("while (Hp < 100) itemheal 10,0;")
    end
  end
end
