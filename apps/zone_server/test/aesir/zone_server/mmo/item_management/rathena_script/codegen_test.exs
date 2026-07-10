defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CodegenTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Codegen
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Lexer
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Parser

  describe "generate/1 healing commands" do
    test "itemheal omits sp when zero" do
      assert {:ok, "heal(ctx, hp: 45)"} = Codegen.generate([{:call, "itemheal", [45, 0]}])
    end

    test "itemheal omits hp when zero" do
      assert {:ok, "heal(ctx, sp: 30)"} = Codegen.generate([{:call, "itemheal", [0, 30]}])
    end

    test "itemheal keeps both hp and sp" do
      assert {:ok, "heal(ctx, hp: 45, sp: 30)"} =
               Codegen.generate([{:call, "itemheal", [45, 30]}])
    end

    test "itemheal with rand(a,b) emits a range" do
      ast = [{:call, "itemheal", [{:call_expr, "rand", [45, 65]}, 0]}]
      assert {:ok, "heal(ctx, hp: 45..65)"} = Codegen.generate(ast)
    end

    test "itemheal with rand(n) emits a 0-based range" do
      ast = [{:call, "itemheal", [{:call_expr, "rand", [100]}, 0]}]
      assert {:ok, "heal(ctx, hp: 0..99)"} = Codegen.generate(ast)
    end

    test "percentheal maps to percent_heal" do
      assert {:ok, "percent_heal(ctx, hp: 50)"} =
               Codegen.generate([{:call, "percentheal", [50, 0]}])
    end

    test "heal maps to heal" do
      assert {:ok, "heal(ctx, hp: 100)"} = Codegen.generate([{:call, "heal", [100, 0]}])
    end
  end

  describe "generate/1 status commands" do
    test "sc_start resolves the status constant" do
      ast = [{:call, "sc_start", [{:const, "SC_BLESSING"}, 60_000, 10]}]
      assert {:ok, "sc_start(ctx, :sc_blessing, 60000, 10)"} = Codegen.generate(ast)
    end

    test "sc_start with rate wraps the call in a random-roll guard" do
      ast = [{:call, "sc_start", [{:const, "SC_FREEZE"}, 10_000, 0, 2500, 0]}]

      assert {:ok,
              "if(Enum.random(1..10_000) <= 2500, do: sc_start(ctx, :sc_freeze, 10000, 0), else: ctx)"} =
               Codegen.generate(ast)
    end

    test "sc_start with a 10000 rate collapses to the plain call" do
      ast = [{:call, "sc_start", [{:const, "SC_STUN"}, 3000, 0, 10_000, 0]}]
      assert {:ok, "sc_start(ctx, :sc_stun, 3000, 0)"} = Codegen.generate(ast)
    end

    test "sc_start GID-targeted six-arg form is unsupported" do
      ast = [{:call, "sc_start", [{:const, "SC_BLIND"}, 2000, 0, 1500, 0, 12_345]}]
      assert {:error, {:unsupported, _}} = Codegen.generate(ast)
    end

    test "sc_end resolves the status constant" do
      ast = [{:call, "sc_end", [{:const, "SC_BLESSING"}]}]
      assert {:ok, "sc_end(ctx, :sc_blessing)"} = Codegen.generate(ast)
    end

    test "unknown status is unsupported" do
      ast = [{:call, "sc_start", [{:const, "SC_NOPE"}, 1, 1]}]
      assert {:error, {:unsupported, _}} = Codegen.generate(ast)
    end

    test "char var increment emits a set_char_var/get_char_var round-trip" do
      ast = [{:incr, "RouletteGold", 1}]

      assert {:ok, "set_char_var(ctx, :RouletteGold, get_char_var(ctx, :RouletteGold, 0) + 1)"} =
               Codegen.generate(ast)
    end

    test "char var decrement emits a minus round-trip" do
      ast = [{:incr, "RouletteGold", -1}]

      assert {:ok, "set_char_var(ctx, :RouletteGold, get_char_var(ctx, :RouletteGold, 0) - 1)"} =
               Codegen.generate(ast)
    end

    test "specialeffect2 resolves an EF_ constant to its effect atom" do
      ast = [{:call, "specialeffect2", [{:const, "EF_HEAL2"}]}]
      assert {:ok, "specialeffect2(ctx, :heal2)"} = Codegen.generate(ast)
    end

    test "unknown special effect is unsupported" do
      ast = [{:call, "specialeffect2", [{:const, "EF_NOPE"}]}]
      assert {:error, {:unsupported, {:unknown_symbol, "EF_NOPE"}}} = Codegen.generate(ast)
    end
  end

  describe "generate/1 control flow" do
    test "if/else emits parseable Elixir" do
      ast = [
        {:if, {:binop, :>, {:read, "BaseLevel"}, 70}, [{:call, "itemheal", [100, 0]}],
         [{:call, "itemheal", [50, 0]}]}
      ]

      assert {:ok, source} = Codegen.generate(ast)
      assert Code.string_to_quoted!(source)
    end

    test "if/else parsed from source emits parseable Elixir" do
      {:ok, tokens} = Lexer.tokenize("if (BaseLevel > 70) itemheal 100,0; else itemheal 50,0;")
      {:ok, ast} = Parser.parse(tokens)

      assert {:ok, source} = Codegen.generate(ast)
      assert Code.string_to_quoted!(source)
    end

    test "if without else returns ctx in the empty branch" do
      ast = [{:if, {:binop, :==, {:read, "Sex"}, 1}, [{:call, "itemheal", [10, 0]}], []}]
      assert {:ok, source} = Codegen.generate(ast)
      assert Code.string_to_quoted!(source)
    end

    test "class branch resolves a Job_ constant" do
      ast = [
        {:if, {:binop, :==, {:read, "Class"}, {:const, "Job_Knight"}},
         [{:call, "sc_start", [{:const, "SC_BLESSING"}, 60_000, 10]}], []}
      ]

      assert {:ok, source} = Codegen.generate(ast)
      assert Code.string_to_quoted!(source)
      assert source =~ ":knight"
    end
  end

  describe "generate/1 multi-statement threading" do
    test "sequential statements thread ctx through a rebinding block" do
      ast = [
        {:call, "itemheal", [45, 0]},
        {:call, "sc_start", [{:const, "SC_BLESSING"}, 60_000, 10]}
      ]

      assert {:ok, source} = Codegen.generate(ast)
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
      assert {:ok, "give_item(ctx, 501, 1)"} =
               Codegen.generate([{:call, "getitem", [{:const, "Red_Potion"}, 1]}])
    end

    test "delitem resolves a numeric id" do
      assert {:ok, "delitem(ctx, 501, 2)"} = Codegen.generate([{:call, "delitem", [501, 2]}])
    end

    test "warp emits literal coords" do
      assert {:ok, "warp(ctx, \"prontera\", 155, 183)"} =
               Codegen.generate([{:call, "warp", ["prontera", 155, 183]}])
    end

    test "warp \"Random\" emits the random-cell form (fly wing)" do
      assert {:ok, "warp(ctx, :random)"} =
               Codegen.generate([{:call, "warp", ["Random", 0, 0]}])
    end

    test "warp \"SavePoint\" emits the save-point form (butterfly wing)" do
      assert {:ok, "warp(ctx, :save_point)"} =
               Codegen.generate([{:call, "warp", ["SavePoint", 0, 0]}])
    end
  end

  describe "generate/1 announce broadcasts" do
    test "announce with a single bc_ flag resolves it to its integer value" do
      assert {:ok, "announce(ctx, \"hi\", 3)"} =
               Codegen.generate([{:call, "announce", ["hi", {:const, "bc_self"}]}])
    end

    test "broadcast maps to the broadcast DSL call" do
      assert {:ok, "broadcast(ctx, \"hi\", 0)"} =
               Codegen.generate([{:call, "broadcast", ["hi", {:const, "bc_all"}]}])
    end

    test "mapannounce keeps the map and text before the flag" do
      assert {:ok, "mapannounce(ctx, \"prontera\", \"hi\", 1)"} =
               Codegen.generate([{:call, "mapannounce", ["prontera", "hi", {:const, "bc_map"}]}])
    end

    test "areaannounce keeps the rectangle, text and flag" do
      ast = [{:call, "areaannounce", ["prontera", 10, 10, 20, 20, "hi", {:const, "bc_area"}]}]

      assert {:ok, "areaannounce(ctx, \"prontera\", 10, 10, 20, 20, \"hi\", 2)"} =
               Codegen.generate(ast)
    end

    test "announce passes a decimal color through after the flag" do
      ast = [{:call, "announce", ["hi", {:const, "bc_all"}, 16_711_680]}]
      assert {:ok, "announce(ctx, \"hi\", 0, 16711680)"} = Codegen.generate(ast)
    end

    test "announce drops the trailing font tail beyond the color" do
      ast = [{:call, "announce", ["hi", {:const, "bc_all"}, 16_711_680, 400, 12, 0, 0]}]
      assert {:ok, "announce(ctx, \"hi\", 0, 16711680)"} = Codegen.generate(ast)
    end

    test "an unresolvable flag const is unsupported, not a raise" do
      assert {:error, {:unsupported, _}} =
               Codegen.generate([{:call, "announce", ["hi", {:const, "bc_nope"}]}])
    end

    test "an announce item that used to fail all-or-nothing now compiles end to end" do
      {:ok, tokens} = Lexer.tokenize(~s(announce "Hello", bc_all;))
      {:ok, ast} = Parser.parse(tokens)

      assert {:ok, "announce(ctx, \"Hello\", 0)"} = Codegen.generate(ast)
    end
  end

  describe "generate/1 unsupported" do
    test "an unknown command is unsupported with its name" do
      assert {:error, {:unsupported, "produce"}} =
               Codegen.generate([{:call, "produce", [999, 1]}])
    end
  end
end
