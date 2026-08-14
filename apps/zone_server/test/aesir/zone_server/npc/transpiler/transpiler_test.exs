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
  test "same-named NPCs in one file take a coordinate suffix instead of conflicting", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "cities"))

    File.write!(Path.join(npc_dir, "cities/kafra.txt"), """
    prontera,150,150,4\tscript\tKafra Service#a\t113,{
    mes "A";
    close;
    }
    prontera,160,160,4\tscript\tKafra Service\t113,{
    mes "B";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert result.conflicts == []

    assert Enum.sort(result.written) ==
             Enum.sort([
               "lib/aesir/zone_server/content/npc/cities/kafra/kafra_service.ex",
               "lib/aesir/zone_server/content/npc/cities/kafra/kafra_service_160_160.ex"
             ])

    first =
      File.read!(
        Path.join(out_root, "lib/aesir/zone_server/content/npc/cities/kafra/kafra_service.ex")
      )

    second =
      File.read!(
        Path.join(
          out_root,
          "lib/aesir/zone_server/content/npc/cities/kafra/kafra_service_160_160.ex"
        )
      )

    assert first =~ ~S{mes("A")}
    assert second =~ ~S{mes("B")}
  end

  @tag :tmp_dir
  test "a duplicate in a later batch attaches to a source transpiled earlier", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "cities"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "cities/guard.txt"), """
    -\tscript\t::GuardFloat\t-1,{
    mes "Halt";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "cities/**")

    assert first.orphan_duplicates == []
    assert [source_path] = first.written
    refute File.read!(Path.join(out_root, source_path)) =~ "x: 100"

    File.write!(Path.join(npc_dir, "re/guard_dup.txt"), """
    izlude,100,100,4\tduplicate(GuardFloat)\tGuard#iz1\t105
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert second.orphan_duplicates == []
    assert second.failures == []
    assert [^source_path] = second.written

    source = File.read!(Path.join(out_root, source_path))
    assert source =~ ~S{map: "izlude"}
    assert source =~ "x: 100"

    # Re-running the same batch is idempotent: nothing new to merge.
    third = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")
    assert third.skipped == 1
    assert third.written == []
  end

  @tag :tmp_dir
  test "a placed script mirrors its rAthena source path", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "cities"))

    File.write!(Path.join(npc_dir, "cities/morocc.txt"), """
    prontera,150,150,4\tscript\tTurban Thief\t54,{
    mes "Hi";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []

    assert ["lib/aesir/zone_server/content/npc/cities/morocc/turban_thief.ex" = rel_path] =
             result.written

    source = File.read!(Path.join(out_root, rel_path))
    assert source =~ "defmodule Aesir.ZoneServer.Content.Npc.Cities.Morocc.TurbanThief do"
  end

  @tag :tmp_dir
  test "nested source directories are preserved and slugged", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "re/jobs/1-1"))

    File.write!(Path.join(npc_dir, "re/jobs/1-1/swordman.txt"), """
    izlude,150,150,4\tscript\tJob Master\t54,{
    mes "Hi";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []

    assert ["lib/aesir/zone_server/content/npc/re/jobs/1_1/swordman/job_master.ex" = rel_path] =
             result.written

    source = File.read!(Path.join(out_root, rel_path))
    assert source =~ "defmodule Aesir.ZoneServer.Content.Npc.Re.Jobs.M11.Swordman.JobMaster do"
  end
end
