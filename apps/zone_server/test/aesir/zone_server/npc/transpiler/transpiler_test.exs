defmodule Aesir.ZoneServer.Npc.Transpiler.TranspilerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler

  @tag :tmp_dir
  test "a touch header threads a trigger and a Display::Exname threads a unique_name", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(npc_dir)

    File.write!(Path.join(npc_dir, "guard.txt"), """
    prontera,150,150,4\tscript\tGuard#g1::GuardEx\t54,2,2,{
    mes "Hi";
    close;

    OnTouch:
    mes "Touched";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert [rel_path] = result.written

    source = File.read!(Path.join(out_root, rel_path))
    assert {:ok, _} = Code.string_to_quoted(source)
    assert source =~ ~S|name: "Guard"|
    assert source =~ ~S|unique_name: "GuardEx"|
    assert source =~ "trigger: {2, 2}"
  end

  @tag :tmp_dir
  test "duplicates resolve their source through the :: export name", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(npc_dir)

    File.write!(Path.join(npc_dir, "bank.txt"), """
    prontera,150,150,4\tscript\tBank Clerk#1::BankClerk\t86,{
    mes "Hi";
    close;
    }
    prontera,160,160,4\tduplicate(BankClerk)\tBank Clerk#2\t86
    """)

    File.write!(Path.join(npc_dir, "guard.txt"), """
    -\tscript\t::GuardFloat\t-1,{
    mes "Halt";
    close;
    }
    izlude,100,100,4\tduplicate(GuardFloat)\tGuard#iz1\t105
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert result.orphan_duplicates == []
    assert length(result.written) == 2

    bank = Enum.find(result.written, &(&1 =~ "bank_clerk"))
    source = File.read!(Path.join(out_root, bank))
    assert source =~ "x: 150"
    assert source =~ "x: 160"
    assert source =~ ~S|unique_name: "BankClerk"|
    assert source =~ ~S|unique_name: "Bank Clerk#2"|

    guard = Enum.find(result.written, &(&1 =~ "guard"))
    guard_source = File.read!(Path.join(out_root, guard))
    assert guard_source =~ "x: 100"
  end

  @tag :tmp_dir
  test "a placement without touch dims or a :: exname omits both keys", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(npc_dir)

    File.write!(Path.join(npc_dir, "plain.txt"), """
    prontera,150,150,4\tscript\tPlain Guy\t54,{
    mes "Hi";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert [rel_path] = result.written

    source = File.read!(Path.join(out_root, rel_path))
    refute source =~ "trigger:"
    refute source =~ "unique_name:"
  end

  @tag :tmp_dir
  test "a cross-run name collision takes a coordinate suffix instead of conflicting", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(npc_dir)

    File.write!(Path.join(npc_dir, "a.txt"), """
    prontera,150,150,4\tscript\tKafra Service#a\t113,{
    mes "A";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root)
    assert ["lib/aesir/zone_server/content/npc/prontera/kafra_service.ex" = owned] = first.written

    File.write!(Path.join(npc_dir, "b.txt"), """
    prontera,160,160,4\tscript\tKafra Service\t113,{
    mes "B";
    close;
    }
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.conflicts == []
    assert second.skipped == 1

    assert second.written == [
             "lib/aesir/zone_server/content/npc/prontera/kafra_service_160_160.ex"
           ]

    refute File.read!(Path.join(out_root, owned)) =~ ~S{mes("B")}
  end
end
