defmodule Aesir.ZoneServer.Npc.Transpiler.AnalyzerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Analyzer
  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  defp analyze!(body) do
    {:ok, ast} = Parser.parse_body(body)
    Analyzer.analyze(ast)
  end

  test "labels in source order, jump vs callsub vs event classification" do
    a =
      analyze!("""
      OnInit:
      end;
      L_Start:
      menu "Buy",L_Buy,"Bye",L_Start;
      L_Buy:
      callsub S_Give, 1;
      goto L_Start;
      S_Give:
      return;
      OnTouch:
      end;
      """)

    assert a.labels == ["OnInit", "L_Start", "L_Buy", "S_Give", "OnTouch"]
    assert MapSet.equal?(a.jump_targets, MapSet.new(["l_buy", "l_start"]))
    assert MapSet.equal?(a.callsub_targets, MapSet.new(["s_give"]))
    assert a.events == ["OnInit", "OnTouch"]
  end

  test "assigned bare names are collected from assignments, input and setarray" do
    a =
      analyze!("""
      sphmask_q = 1;
      input questname$;
      setarray quests[0], 1, 2;
      if (MISC_QUEST & 8) close;
      """)

    assert MapSet.equal?(a.assigned_names, MapSet.new(["sphmask_q", "questname$", "quests"]))
  end

  test "natively-shaped and mapped buildins do not count as stubs" do
    a =
      analyze!("""
      dispbottom "hi";
      setcart;
      openstorage;
      deletearray quests[0];
      .@n = getarraysize(.@a) + getcharid(0) + checkcart() + getskilllv(39);
      .@s$ = implode(.@a$, ",");
      close3;
      """)

    assert a.stubs == %{}
    assert MapSet.member?(a.assigned_names, "quests")
  end

  test "skill grants and native job-lineage reads do not count as stubs" do
    a =
      analyze!("""
      skill "NV_FIRSTAID",1,SKILL_PERM;
      if (BaseClass == Job_Archer) skill 147,1,SKILL_PERM;
      if (BaseJob == Job_Hunter) skill "HT_PHANTASMIC",1,SKILL_PERM;
      """)

    assert a.stubs == %{}
  end

  test "stubs count unsupported buildins by call site, in statements and expressions" do
    a =
      analyze!("""
      getitem 501, 1;
      showscript "hi";
      showscript "again";
      if (getgmlevel() == 0) close;
      mes "item " + getitemname(501);
      """)

    assert a.stubs == %{"showscript" => 2, "getgmlevel" => 1, "getitemname" => 1}
  end

  test "local functions are not stubs" do
    a =
      analyze!("""
      function GuardianData;
      GuardianData(1);
      function GuardianData {
        return getarg(0);
      }
      """)

    assert MapSet.member?(a.local_functions, "GuardianData")
    assert a.stubs == %{}
  end
end
