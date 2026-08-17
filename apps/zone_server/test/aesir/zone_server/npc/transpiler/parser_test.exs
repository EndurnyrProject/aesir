defmodule Aesir.ZoneServer.Npc.Transpiler.ParserTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  describe "expressions and simple statements" do
    test "command statement without parens" do
      assert {:ok, [{:cmd, "getitem", [{:int, 501}, {:int, 1}]}]} =
               Parser.parse_body("getitem 501,1;")
    end

    test "command statement with parens and bare command" do
      assert {:ok, [{:cmd, "callfunc", [{:str, "F_X"}, {:int, 1}]}, {:cmd, "close", []}]} =
               Parser.parse_body(~s{callfunc("F_X", 1); close;})
    end

    test "the jA-compat Select alias normalizes to the select primitive" do
      assert {:ok, [{:cmd, "select", [{:str, "A:B:C"}]}]} =
               Parser.parse_body(~s{Select("A:B:C");})

      assert {:ok, [{:assign, _target, {:call, "select", [{:str, "A"}, {:str, "B"}]}}]} =
               Parser.parse_body(~s{.@i = Select("A", "B");})
    end

    test "set and operator assignments desugar to plain assigns" do
      assert {:ok,
              [
                {:assign, {:var, :local, "a", :int}, {:int, 1}},
                {:assign, {:var, :local, "a", :int}, {:int, 2}},
                {:assign, {:var, :local, "a", :int},
                 {:bin, :+, {:var, :local, "a", :int}, {:int, 3}}},
                {:assign, {:var, :local, "a", :int},
                 {:bin, :+, {:var, :local, "a", :int}, {:int, 1}}}
              ]} = Parser.parse_body("set .@a, 1; .@a = 2; .@a += 3; .@a++;")
    end

    test "bare-name assignment and array element assignment" do
      assert {:ok,
              [
                {:assign, {:name, "sphmask_q"}, {:int, 1}},
                {:assign, {:index, {:var, :local, "list", :int}, {:int, 0}}, {:int, 5}}
              ]} = Parser.parse_body("sphmask_q = 1; .@list[0] = 5;")
    end

    test "precedence matches C" do
      assert {:ok, [{:cmd, "x", [expr]}]} = Parser.parse_body("x 1 + 2 * 3;")
      assert expr == {:bin, :+, {:int, 1}, {:bin, :*, {:int, 2}, {:int, 3}}}

      assert {:ok, [{:cmd, "x", [expr]}]} = Parser.parse_body("x a || b && c;")
      assert expr == {:bin, :||, {:name, "a"}, {:bin, :&&, {:name, "b"}, {:name, "c"}}}
    end

    test "ternary is right-associative" do
      assert {:ok, [{:cmd, "x", [expr]}]} = Parser.parse_body("x a ? 1 : b ? 2 : 3;")

      assert expr ==
               {:ternary, {:name, "a"}, {:int, 1}, {:ternary, {:name, "b"}, {:int, 2}, {:int, 3}}}
    end

    test "string concat, calls in expressions, array refs, unary ops" do
      assert {:ok, [{:cmd, "mes", [expr]}]} =
               Parser.parse_body(~s{mes "Hello " + strcharinfo(0) + "!";})

      assert expr ==
               {:bin, :+, {:bin, :+, {:str, "Hello "}, {:call, "strcharinfo", [{:int, 0}]}},
                {:str, "!"}}

      assert {:ok, [{:cmd, "x", [{:neg, {:int, 1}}, {:not, {:name, "a"}}]}]} =
               Parser.parse_body("x -1, !a;")

      assert {:ok, [{:cmd, "x", [{:index, {:var, :session, "arr", :int}, {:name, "i"}}]}]} =
               Parser.parse_body("x @arr[i];")
    end

    test "parse errors return an error tuple, never raise" do
      assert {:error, _} = Parser.parse_body("if (")
      assert {:error, _} = Parser.parse_body("x = ;")
    end
  end

  describe "control flow" do
    test "if / else if / else, braceless bodies" do
      assert {:ok, [{:if, {:bin, :>=, {:name, "Zeny"}, {:int, 50}}, [then_stmt], else_stmts}]} =
               Parser.parse_body("""
               if (Zeny >= 50) close;
               else if (BaseLevel > 10) { next; }
               else end;
               """)

      assert then_stmt == {:cmd, "close", []}
      assert [{:if, _, [{:cmd, "next", []}], [{:cmd, "end", []}]}] = else_stmts
    end

    test "if condition is a full expression, not just the first paren group" do
      assert {:ok, [{:if, cond_expr, [then_stmt], []}]} =
               Parser.parse_body("if (countitem(7201) > 499) && (moza_tal == 1) close;")

      assert cond_expr ==
               {:bin, :&&, {:bin, :>, {:call, "countitem", [{:int, 7201}]}, {:int, 499}},
                {:bin, :==, {:name, "moza_tal"}, {:int, 1}}}

      assert then_stmt == {:cmd, "close", []}
    end

    test "switch with fall-through case labels and default" do
      assert {:ok, [{:switch, {:call, "select", _}, clauses}]} =
               Parser.parse_body("""
               switch (select("A:B:C")) {
               case 1:
               case 2:
                 mes "ab";
                 break;
               default:
                 close;
               }
               """)

      assert [
               {[{:int, 1}, {:int, 2}], [{:cmd, "mes", _}, {:break}]},
               {[:default], [{:cmd, "close", []}]}
             ] =
               clauses
    end

    test "while, do-while and for loops" do
      assert {:ok, [{:while, _, [{:assign, _, _}]}]} =
               Parser.parse_body("while (.@i < 3) .@i++;")

      assert {:ok, [{:do_while, [{:cmd, "mes", _}], {:bin, :<, _, _}}]} =
               Parser.parse_body(~S|do { mes "x"; } while (.@i < 3);|)

      assert {:ok, [{:for, [init], cond_expr, [step], body}]} =
               Parser.parse_body(~s{for (.@i = 0; .@i < 10; .@i++) mes "i";})

      assert {:assign, {:var, :local, "i", :int}, {:int, 0}} = init
      assert {:bin, :<, _, {:int, 10}} = cond_expr
      assert {:assign, _, {:bin, :+, _, {:int, 1}}} = step
      assert [{:cmd, "mes", _}] = body
    end

    test "labels, goto and menu" do
      assert {:ok,
              [
                {:label, "L_Start"},
                {:menu, [{{:str, "Buy"}, "L_Buy"}, {{:str, "Leave"}, "L_Start"}]},
                {:label, "L_Buy"},
                {:goto, "L_Start"}
              ]} =
               Parser.parse_body("""
               L_Start:
               menu "Buy",L_Buy,"Leave",L_Start;
               L_Buy:
               goto L_Start;
               """)
    end

    test "callsub and return with value" do
      assert {:ok,
              [
                {:cmd, "callsub", [{:name, "S_Give"}, {:int, 5}]},
                {:label, "S_Give"},
                {:return, {:bin, :+, {:call, "getarg", [{:int, 0}]}, {:int, 1}}}
              ]} =
               Parser.parse_body("""
               callsub S_Give, 5;
               S_Give:
               return getarg(0) + 1;
               """)

      assert {:ok, [{:return, nil}]} = Parser.parse_body("return;")
    end

    test "chained assignment desugars innermost-first" do
      assert {:ok, [{:block, [{:assign, b, {:int, 0}}, {:assign, a, b}]}]} =
               Parser.parse_body("'a = 'b = 0;")

      assert a == {:var, :instance, "a", :int}
      assert b == {:var, :instance, "b", :int}
    end

    test "script-local function declaration and definition" do
      assert {:ok, [{:fn_decl, "GuardianData"}, {:function, "GuardianData", [{:return, nil}]}]} =
               Parser.parse_body("function GuardianData; function GuardianData { return; }")
    end

    test "parenthesized first argument with ternary backs off the call form" do
      assert {:ok, [{:cmd, "emotion", [{:ternary, _, {:name, "ET_MONEY"}, {:name, "ET_HUK"}}]}]} =
               Parser.parse_body("emotion (Zeny > 50) ? ET_MONEY : ET_HUK;")
    end

    test "for with comma-separated init and postfix increment in expressions" do
      assert {:ok, [{:for, [_, _], _, [_], _}]} =
               Parser.parse_body(~S|for (.@i = 0, .@j = 1; .@i < 5; .@i++) mes "x";|)

      assert {:ok, [{:cmd, "x", [{:index, _, {:post_inc, {:var, :local, "i", :int}}}]}]} =
               Parser.parse_body("x .@arr[.@i++];")
    end

    test "dead statements before the first case are dropped" do
      assert {:ok, [{:switch, _, [{[{:int, 1}], [{:cmd, "close", []}]}]}]} =
               Parser.parse_body(~S|switch (select("A")) { mes "dead"; case 1: close; }|)
    end

    test "a realistic full body parses end to end" do
      body = """
      mes "[Turban Thief]";
      mes "Want to buy a mask?";
      next;
      switch (select("Yes:No")) {
      case 1:
        if (Zeny < 500) {
          mes "Too poor!";
          close;
        }
        Zeny -= 500;
        getitem 2278, 1;
        sphmask_q = 1;
        close;
      case 2:
        close;
      }
      """

      assert {:ok, stmts} = Parser.parse_body(body)
      assert [{:cmd, "mes", _}, {:cmd, "mes", _}, {:cmd, "next", []}, {:switch, _, _}] = stmts
    end
  end
end
