defmodule Aesir.ZoneServer.Npc.Transpiler.FileParserTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.FileParser

  test "parses a placed script NPC with body and constant sprite" do
    source = """
    // a header comment
    izlude,122,105,5\tscript\tChannel Warp Official\t1_M_WIZARD,{
    \tmes "hi";
    \tclose;
    }
    """

    assert {:ok, [entry]} = FileParser.parse(source, "izlude.txt")

    assert %{
             kind: :script,
             map: "izlude",
             x: 122,
             y: 105,
             dir: 5,
             name: "Channel Warp Official",
             sprite: "1_M_WIZARD",
             touch: nil,
             file: "izlude.txt",
             line: 2
           } = entry

    assert entry.body =~ ~s(mes "hi";)
    assert entry.body =~ "close;"
  end

  test "parses a one-line body and a numeric sprite with touch area" do
    source =
      ~s(izlude,1,2,3\tscript\tOneliner\t545,2,2,{ mes "x"; close; }\n) <>
        ~s(payon,10,20,4\tscript\tAfter\t111,{\n\tclose;\n}\n)

    assert {:ok, [one, two]} = FileParser.parse(source)

    assert %{kind: :script, sprite: 545, touch: {2, 2}, body: body, line: 1} = one
    assert body =~ ~s(mes "x";)
    assert %{kind: :script, name: "After", sprite: 111, line: 2} = two
  end

  test "parses floating scripts, functions, and duplicates" do
    source = """
    -\tscript\t::Guard_izlude\t-1,{
    \tend;
    }
    function\tscript\tF_ClearJobVar\t{
    \treturn;
    }
    prontera,52,344,5\tduplicate(prtguard)\tGuard#1pront\t105
    te_prt_gld,129,65,0\tduplicate(warp_TE_castle)\tprtg-1#1_te\tWARPNPC,1,1
    """

    assert {:ok, [floating, function, dup1, dup2]} = FileParser.parse(source)

    assert %{kind: :floating, name: "::Guard_izlude", sprite: -1} = floating
    assert floating.body =~ "end;"

    assert %{kind: :function, name: "F_ClearJobVar"} = function
    assert function.body =~ "return;"

    assert %{kind: :duplicate, source: "prtguard", name: "Guard#1pront", sprite: 105, touch: nil} =
             dup1

    assert %{kind: :duplicate, source: "warp_TE_castle", sprite: "WARPNPC", touch: {1, 1}} = dup2
  end

  test "skips shop-family and mapflag lines, drops warp and monster lines" do
    source = """
    alberta,28,29,0\tshop\tTool Dealer\t83,501:-1,502:-1
    prontera\tmapflag\tnowarp
    prontera,100,100,0\twarp\tprt001\t2,2,izlude,10,10
    prt_fild08,0,0,0,0\tmonster\tPoring\t1002,70,5000,0,0
    """

    assert {:ok, [shop, mapflag]} = FileParser.parse(source)
    assert %{kind: :skipped, type: "shop", line: 1} = shop
    assert %{kind: :skipped, type: "mapflag", line: 2} = mapflag
  end

  test "braces inside strings and comments do not break body extraction" do
    source = """
    payon,1,1,1\tscript\tBracey\t111,{
    \tmes "a { brace } in a string";
    \t// a } in a line comment
    \t/* a { in a block
    \t   comment } */
    \tif (1) { close; }
    }
    payon,2,2,2\tscript\tNext\t111,{ close; }
    """

    assert {:ok, [bracey, next_npc]} = FileParser.parse(source)
    assert bracey.body =~ "a { brace } in a string"
    assert bracey.body =~ "if (1) { close; }"
    refute bracey.body =~ "line comment"
    assert %{kind: :script, name: "Next", line: 8} = next_npc
  end

  test "a malformed header yields an error entry, consumes its body, and parsing continues" do
    source = """
    not_a_position\tscript\tBroken\t111,{
    \tmes "inside";
    }
    payon,2,2,2\tscript\tStill Works\t111,{ close; }
    """

    assert {:ok, [%{kind: :error, reason: {:bad_placement, "not_a_position"}}, %{kind: :script}]} =
             FileParser.parse(source)

    source2 = """
    what is this line even
    payon,2,2,2\tscript\tStill Works\t111,{ close; }
    """

    assert {:ok, [%{kind: :error, reason: {:unrecognized, _}}, %{kind: :script}]} =
             FileParser.parse(source2)
  end

  test "an unterminated body yields an error entry" do
    source = """
    payon,1,1,1\tscript\tNever Ends\t111,{
    \tmes "no closing brace";
    """

    assert {:ok, [%{kind: :error, reason: :unterminated_body}]} = FileParser.parse(source)
  end
end
