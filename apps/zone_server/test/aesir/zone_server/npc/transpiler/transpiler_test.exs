defmodule Aesir.ZoneServer.Npc.Transpiler.TranspilerTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler
  alias Aesir.ZoneServer.Npc.Transpiler.Manifest

  defp run_enabled(root, out_root) do
    enable_all_sources!(root)
    Transpiler.run(root, out_root: out_root)
  end

  defp enable_all_sources!(root) do
    npc_root = Path.join(root, "npc")

    sources =
      npc_root
      |> Path.join("**/*.txt")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, npc_root))
      |> Enum.sort()

    shared = Enum.reject(sources, &String.starts_with?(&1, ["re/", "pre-re/"]))
    renewal = Enum.filter(sources, &String.starts_with?(&1, "re/"))
    pre_renewal = Enum.filter(sources, &String.starts_with?(&1, "pre-re/"))

    write_main!(root, "re", shared ++ renewal)
    write_main!(root, "pre-re", shared ++ pre_renewal)
  end

  defp write_main!(root, mode_dir, sources) do
    path = Path.join([root, "npc", mode_dir, "scripts_main.conf"])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Enum.map_join(sources, "", &"npc: npc/#{&1}\n"))
  end

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
    result = run_enabled(tmp_dir, out_root)

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
    result = run_enabled(tmp_dir, out_root)

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
    result = run_enabled(tmp_dir, out_root)

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
    result = run_enabled(tmp_dir, out_root)

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
  test "a source-present manifest script with no module is recovered for cross-run linking", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared/guard.txt"), """
    -\tscript\t::GuardFloat\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []
    assert [source_path] = first.written

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "shared/guard.txt|floating|::GuardFloat|-"
    manifest = Manifest.load(manifest_path)
    expected_module = manifest[key].module
    Manifest.save(put_in(manifest, [key, :module], nil), manifest_path)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(GuardFloat)\tRenewal Guard\t54
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert second.failures == []
    assert second.orphan_duplicates == []
    assert second.written == [source_path]
    assert File.read!(Path.join(out_root, source_path)) =~ ~S|map: "izlude"|
    assert Manifest.load(manifest_path)[key].module == expected_module
  end

  @tag :tmp_dir
  test "a source-missing manifest script with no module fails explicitly", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    source_file = Path.join(npc_dir, "shared/guard.txt")

    File.write!(source_file, """
    -\tscript\t::GuardFloat\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "shared/guard.txt|floating|::GuardFloat|-"
    manifest = Manifest.load(manifest_path)
    Manifest.save(put_in(manifest, [key, :module], nil), manifest_path)
    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)
    File.rm!(source_file)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(GuardFloat)\tRenewal Guard\t54
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert second.failures == [
             {:link, "shared/guard.txt", 0,
              {:missing_manifest_module, key, "shared/guard.txt", :shared}}
           ]

    assert second.orphan_duplicates == []
    assert second.written == []
    assert File.read!(manifest_path) == manifest_before
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
    result = run_enabled(tmp_dir, out_root)

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
    result = run_enabled(tmp_dir, out_root)

    assert result.failures == []

    assert ["lib/aesir/zone_server/content/npc/re/jobs/1_1/swordman/job_master.ex" = rel_path] =
             result.written

    source = File.read!(Path.join(out_root, rel_path))
    assert source =~ "defmodule Aesir.ZoneServer.Content.Npc.Re.Jobs.M11.Swordman.JobMaster do"
  end

  @tag :tmp_dir
  test "one enabled-graph run emits scoped bodies, placements, helpers and floating modules", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))
    File.mkdir_p!(Path.join(npc_dir, "pre-re"))

    File.write!(Path.join(npc_dir, "shared/main.txt"), """
    -\tscript\t::GuardFloat\t-1,{
    close;
    }
    prontera,10,10,4\tduplicate(GuardFloat)\tShared Guard\t54
    prontera,20,20,4\tscript\tShared Caller\t54,{
    callfunc "F_Shared";
    callfunc "F_Mode";
    close;
    }
    function\tscript\tF_Shared\t{
    return;
    }
    """)

    File.write!(Path.join(npc_dir, "re/overlay.txt"), """
    izlude,30,30,4\tduplicate(GuardFloat)\tRenewal Guard\t54
    -\tscript\tOverlay Float\t-1,{
    close;
    }
    function\tscript\tF_Mode\t{
    return 1;
    }
    """)

    File.write!(Path.join(npc_dir, "pre-re/overlay.txt"), """
    morocc,40,40,4\tduplicate(GuardFloat)\tClassic Guard\t54
    -\tscript\tOverlay Float\t-1,{
    close;
    }
    function\tscript\tF_Mode\t{
    return 2;
    }
    """)

    File.write!(Path.join(npc_dir, "disabled.txt"), """
    function\tscript\tF_Disabled\t{
    return;
    }
    """)

    write_main!(tmp_dir, "re", ["shared/main.txt", "re/overlay.txt"])
    write_main!(tmp_dir, "pre-re", ["shared/main.txt", "pre-re/overlay.txt"])

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert result.orphan_duplicates == []

    paths = MapSet.new(result.written)

    assert MapSet.member?(
             paths,
             "lib/aesir/zone_server/content/npc/re/functions/f_mode.ex"
           )

    assert MapSet.member?(
             paths,
             "lib/aesir/zone_server/content/npc/pre_re/functions/f_mode.ex"
           )

    assert MapSet.member?(
             paths,
             "lib/aesir/zone_server/content/npc/re/floating/overlay_float.ex"
           )

    assert MapSet.member?(
             paths,
             "lib/aesir/zone_server/content/npc/pre_re/floating/overlay_float.ex"
           )

    refute Enum.any?(result.written, &String.contains?(&1, "disabled"))

    guard_path =
      "lib/aesir/zone_server/content/npc/floating/guardfloat.ex"

    guard_source = File.read!(Path.join(out_root, guard_path))
    assert guard_source =~ ~S|map: "prontera"|
    assert guard_source =~ ~S|map: "izlude"|
    assert guard_source =~ ~S|map: "morocc"|
    assert guard_source =~ "scope: :shared"
    assert guard_source =~ "scope: :renewal"
    assert guard_source =~ "scope: :pre_renewal"

    caller =
      File.read!(
        Path.join(
          out_root,
          "lib/aesir/zone_server/content/npc/shared/main/shared_caller.ex"
        )
      )

    assert caller =~ "Aesir.ZoneServer.Content.Npc.Functions.FShared.call"
    assert caller =~ "case GameMode.mode() do"
    assert caller =~ "Aesir.ZoneServer.Content.Npc.Re.Functions.FMode.call"
    assert caller =~ "Aesir.ZoneServer.Content.Npc.PreRe.Functions.FMode.call"

    manifest = Manifest.load(Path.join(out_root, "priv/npc_transpile/manifest.json"))

    assert %{spawns: spawns} = manifest["shared/main.txt|floating|::GuardFloat|-"]
    assert Enum.map(spawns, & &1.scope) == [:shared, :renewal, :pre_renewal]
  end

  @tag :tmp_dir
  test "duplicate lookup ignores the opposite overlay and reports scoped orphans", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "re"))
    File.mkdir_p!(Path.join(npc_dir, "pre-re"))

    File.write!(Path.join(npc_dir, "re/source.txt"), """
    -\tscript\t::ModeGuard\t-1,{
    mes "renewal";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "pre-re/source.txt"), """
    -\tscript\t::ModeGuard\t-1,{
    mes "classic";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,50,50,4\tduplicate(ModeGuard)\tRenewal Placement\t54
    """)

    File.write!(Path.join(npc_dir, "orphan.txt"), """
    prontera,60,60,4\tduplicate(ModeGuard)\tShared Placement\t54
    """)

    write_main!(tmp_dir, "re", ["orphan.txt", "re/source.txt", "re/duplicate.txt"])
    write_main!(tmp_dir, "pre-re", ["orphan.txt", "pre-re/source.txt"])

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    assert result.orphan_duplicates == ["ModeGuard [shared]"]

    renewal =
      File.read!(
        Path.join(
          out_root,
          "lib/aesir/zone_server/content/npc/re/floating/modeguard.ex"
        )
      )

    classic =
      File.read!(
        Path.join(
          out_root,
          "lib/aesir/zone_server/content/npc/pre_re/floating/modeguard.ex"
        )
      )

    assert renewal =~ ~S|map: "izlude"|
    refute classic =~ ~S|map: "izlude"|
  end

  @tag :tmp_dir
  test "multiple compatible duplicate sources fail before any output is written", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared.txt"), """
    -\tscript\t::AmbiguousGuard\t-1,{
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/source.txt"), """
    -\tscript\t::AmbiguousGuard\t-1,{
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,70,70,4\tduplicate(AmbiguousGuard)\tAmbiguous Placement\t54
    """)

    write_main!(tmp_dir, "re", ["shared.txt", "re/source.txt", "re/duplicate.txt"])
    write_main!(tmp_dir, "pre-re", ["shared.txt"])

    out_root = Path.join(tmp_dir, "out")
    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert [
             {:link, "re/duplicate.txt", 1,
              {:ambiguous_duplicate, "AmbiguousGuard", :renewal, candidates}}
           ] = result.failures

    assert Enum.sort(candidates) ==
             [{"re/source.txt", :renewal}, {"shared.txt", :shared}]

    assert result.written == []
    refute File.exists?(Path.join(out_root, "priv/npc_transpile/manifest.json"))
  end

  @tag :tmp_dir
  test "authoritative runs exclude stale records from linking and remove untouched outputs", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    function\tscript\tF_Stale\t{
    return 1;
    }
    """)

    out_root = Path.join(tmp_dir, "out")

    first =
      Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert length(first.written) == 2
    stale_paths = Enum.map(first.written, &Path.join(out_root, &1))
    assert Enum.all?(stale_paths, &File.exists?/1)

    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "caller.txt"), """
    prontera,80,80,4\tscript\tCaller\t54,{
    callfunc "F_Stale";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,90,90,4\tduplicate(StaleBody)\tStale Placement\t54
    """)

    write_main!(tmp_dir, "re", ["caller.txt", "re/duplicate.txt"])
    write_main!(tmp_dir, "pre-re", ["caller.txt"])

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.failures == []
    assert second.orphan_duplicates == ["StaleBody [renewal]"]
    refute Enum.any?(stale_paths, &File.exists?/1)

    caller_path =
      "lib/aesir/zone_server/content/npc/caller/caller.ex"

    caller = File.read!(Path.join(out_root, caller_path))
    assert caller =~ ~S|todo(:callfunc, ["F_Stale"])|
    refute caller =~ "Functions.FStale.call"

    manifest = Manifest.load(Path.join(out_root, "priv/npc_transpile/manifest.json"))
    refute Map.has_key?(manifest, "disabled/content.txt|floating|::StaleBody|-")
    refute Map.has_key?(manifest, "disabled/content.txt|function|F_Stale|-")
  end

  @tag :tmp_dir
  test "only runs reject an active manifest path that escapes the output root", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared/guard.txt"), """
    -\tscript\t::GuardFloat\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []
    assert [source_rel_path] = first.written
    source_path = Path.join(out_root, source_rel_path)
    source_before = File.read!(source_path)

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "shared/guard.txt|floating|::GuardFloat|-"
    manifest = Manifest.load(manifest_path)
    Manifest.save(put_in(manifest, [key, :output_path], "../escape.ex"), manifest_path)
    manifest_before = File.read!(manifest_path)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(GuardFloat)\tRenewal Guard\t54
    """)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert result.failures == [
             {:active, "shared/guard.txt", 0,
              {:invalid_output_path, "../escape.ex", :outside_root}}
           ]

    assert result.written == []
    refute File.exists?(Path.join(tmp_dir, "escape.ex"))
    assert File.read!(source_path) == source_before
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "only runs report a non-string active function path without mutating output", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "active"))

    File.write!(Path.join(npc_dir, "active/helper.txt"), """
    function\tscript\tF_Active\t{
    return 1;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert first.failures == []
    assert [output_rel_path] = first.written
    output_path = Path.join(out_root, output_rel_path)
    output_before = File.read!(output_path)

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "active/helper.txt|function|F_Active|-"
    manifest = Manifest.load(manifest_path)
    Manifest.save(put_in(manifest, [key, :output_path], 42), manifest_path)
    manifest_before = File.read!(manifest_path)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert result.failures == [
             {:active, "active/helper.txt", 0, {:invalid_output_path, 42, :non_string}}
           ]

    assert result.written == []
    assert File.read!(output_path) == output_before
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "only runs reject an active manifest path naming the output root", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared/guard.txt"), """
    -\tscript\t::RootGuard\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []
    assert [output_rel_path] = first.written
    output_path = Path.join(out_root, output_rel_path)
    output_before = File.read!(output_path)

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "shared/guard.txt|floating|::RootGuard|-"
    manifest = Manifest.load(manifest_path)
    Manifest.save(put_in(manifest, [key, :output_path], "."), manifest_path)
    manifest_before = File.read!(manifest_path)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(RootGuard)\tRenewal Guard\t54
    """)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert result.failures == [
             {:active, "shared/guard.txt", 0, {:invalid_output_path, ".", :output_root}}
           ]

    assert result.written == []
    assert File.read!(output_path) == output_before
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "invalid active aliases cannot let a stale owner delete the active output", %{
    tmp_dir: tmp_dir
  } do
    Enum.each([:absolute, :symlink], fn path_kind ->
      case_root = Path.join(tmp_dir, Atom.to_string(path_kind))
      npc_dir = Path.join(case_root, "npc")
      out_root = Path.join(case_root, "out")
      output_rel_path = "lib/active.ex"
      output_path = Path.join(out_root, output_rel_path)
      File.mkdir_p!(npc_dir)
      File.mkdir_p!(Path.dirname(output_path))
      File.write!(output_path, "active")
      File.write!(Path.join(npc_dir, "active.txt"), "")
      write_main!(case_root, "re", ["active.txt"])
      write_main!(case_root, "pre-re", ["active.txt"])

      active_output_path =
        case path_kind do
          :absolute ->
            output_path

          :symlink ->
            File.ln_s!(Path.dirname(output_path), Path.join(out_root, "linked"))
            "linked/active.ex"
        end

      record = %{
        source_hash: "source",
        output_path: active_output_path,
        output_hash: Manifest.hash("active"),
        spawns: [],
        module: nil
      }

      manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")

      Manifest.save(
        %{
          "active.txt|function|F_Active|-" => record,
          "disabled.txt|function|F_Stale|-" => %{record | output_path: output_rel_path}
        },
        manifest_path
      )

      manifest_before = File.read!(manifest_path)
      expected_reason = if(path_kind == :absolute, do: :non_relative, else: :symlink)

      result = Transpiler.run(case_root, out_root: out_root)

      assert result.failures == [
               {:active, "active.txt", 0,
                {:invalid_output_path, active_output_path, expected_reason}}
             ]

      assert result.written == []
      assert File.read!(output_path) == "active"
      assert File.read!(manifest_path) == manifest_before
    end)
  end

  @tag :tmp_dir
  test "cross-run recovery uses the canonical active manifest path", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared/guard.txt"), """
    -\tscript\t::CanonicalGuard\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []
    assert [source_rel_path] = first.written

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "shared/guard.txt|floating|::CanonicalGuard|-"
    manifest = Manifest.load(manifest_path)

    aliased_path =
      Path.dirname(source_rel_path) <> "/nested/../" <> Path.basename(source_rel_path)

    Manifest.save(put_in(manifest, [key, :output_path], aliased_path), manifest_path)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(CanonicalGuard)\tRenewal Guard\t54
    """)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    assert result.failures == []
    assert result.written == [source_rel_path]
    assert File.read!(Path.join(out_root, source_rel_path)) =~ ~S|map: "izlude"|
    assert Manifest.load(manifest_path)[key].output_path == source_rel_path
  end

  @tag :tmp_dir
  test "existing manifest keys reuse their canonical output path", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "active"))
    source_path = Path.join(npc_dir, "active/helper.txt")

    File.write!(source_path, """
    function\tscript\tF_Canonical\t{
    return 1;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert first.failures == []
    assert [output_rel_path] = first.written

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key = "active/helper.txt|function|F_Canonical|-"
    manifest = Manifest.load(manifest_path)

    aliased_path =
      Path.dirname(output_rel_path) <> "/nested/../" <> Path.basename(output_rel_path)

    Manifest.save(put_in(manifest, [key, :output_path], aliased_path), manifest_path)

    File.write!(source_path, """
    function\tscript\tF_Canonical\t{
    return 2;
    }
    """)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert result.failures == []
    assert result.written == [output_rel_path]
    assert File.read!(Path.join(out_root, output_rel_path)) =~ "{ctx, 2}"
    assert Manifest.load(manifest_path)[key].output_path == output_rel_path
  end

  @tag :tmp_dir
  test "only runs reject multiple active manifest owners of one canonical output", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc/active")
    File.mkdir_p!(npc_dir)

    File.write!(Path.join(npc_dir, "a.txt"), """
    function\tscript\tF_A\t{
    return 1;
    }
    """)

    File.write!(Path.join(npc_dir, "b.txt"), """
    function\tscript\tF_B\t{
    return 2;
    }
    """)

    File.write!(Path.join(npc_dir, "caller.txt"), """
    prontera,100,100,4\tscript\tCaller\t54,{
    callfunc "F_A";
    callfunc "F_B";
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert first.failures == []
    assert length(first.written) == 3

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    key_a = "active/a.txt|function|F_A|-"
    key_b = "active/b.txt|function|F_B|-"
    manifest = Manifest.load(manifest_path)
    output_a = manifest[key_a].output_path
    output_b = manifest[key_b].output_path

    output_alias = Path.dirname(output_a) <> "/nested/../" <> Path.basename(output_a)
    Manifest.save(put_in(manifest, [key_b, :output_path], output_alias), manifest_path)

    generated_before =
      out_root
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> Map.new(&{Path.relative_to(&1, out_root), File.read!(&1)})

    manifest_before = File.read!(manifest_path)

    result = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert result.failures == [
             {:active, "active/a.txt", 0,
              {:multiple_output_owners, output_a,
               [
                 {key_a, "active/a.txt"},
                 {key_b, "active/b.txt"}
               ]}}
           ]

    assert result.written == []

    generated_after =
      out_root
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> Map.new(&{Path.relative_to(&1, out_root), File.read!(&1)})

    assert generated_after == generated_before
    assert Map.has_key?(generated_after, output_a)
    assert Map.has_key?(generated_after, output_b)
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "authoritative reconciliation rejects absolute and root-escaping stale paths", %{
    tmp_dir: tmp_dir
  } do
    out_root = Path.join(tmp_dir, "out")
    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    absolute_path = Path.join(tmp_dir, "absolute.ex")
    escaped_path = Path.join(tmp_dir, "escaped.ex")
    File.write!(absolute_path, "absolute")
    File.write!(escaped_path, "escaped")

    manifest = %{
      "disabled/absolute.txt|function|F_Absolute|-" => %{
        source_hash: "source",
        output_path: absolute_path,
        output_hash: Manifest.hash("absolute"),
        spawns: [],
        module: nil
      },
      "disabled/escaped.txt|function|F_Escaped|-" => %{
        source_hash: "source",
        output_path: "../escaped.ex",
        output_hash: Manifest.hash("escaped"),
        spawns: [],
        module: nil
      }
    }

    Manifest.save(manifest, manifest_path)
    manifest_before = File.read!(manifest_path)
    write_main!(tmp_dir, "re", [])
    write_main!(tmp_dir, "pre-re", [])

    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert Enum.sort(result.failures) ==
             Enum.sort([
               {:stale, "disabled/absolute.txt", 0,
                {:invalid_output_path, absolute_path, :non_relative}},
               {:stale, "disabled/escaped.txt", 0,
                {:invalid_output_path, "../escaped.ex", :outside_root}}
             ])

    assert result.written == []
    assert File.read!(absolute_path) == "absolute"
    assert File.read!(escaped_path) == "escaped"
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "authoritative reconciliation rejects stale paths through symlinked directories", %{
    tmp_dir: tmp_dir
  } do
    out_root = Path.join(tmp_dir, "out")
    outside_dir = Path.join(tmp_dir, "outside")
    output_path = Path.join(outside_dir, "generated.ex")
    File.mkdir_p!(out_root)
    File.mkdir_p!(outside_dir)
    File.write!(output_path, "generated")
    File.ln_s!(outside_dir, Path.join(out_root, "linked"))

    key = "disabled/symlink.txt|function|F_Symlink|-"

    record = %{
      source_hash: "source",
      output_path: "linked/generated.ex",
      output_hash: Manifest.hash("generated"),
      spawns: [],
      module: nil
    }

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    Manifest.save(%{key => record}, manifest_path)
    manifest_before = File.read!(manifest_path)
    write_main!(tmp_dir, "re", [])
    write_main!(tmp_dir, "pre-re", [])

    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == [
             {:stale, "disabled/symlink.txt", 0,
              {:invalid_output_path, "linked/generated.ex", :symlink}}
           ]

    assert File.read!(output_path) == "generated"
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "authoritative reconciliation groups aliased stale ownership by physical output", %{
    tmp_dir: tmp_dir
  } do
    out_root = Path.join(tmp_dir, "out")
    output_rel_path = "lib/shared.ex"
    output_path = Path.join(out_root, output_rel_path)
    File.mkdir_p!(Path.dirname(output_path))
    File.write!(output_path, "generated")

    record = %{
      source_hash: "source",
      output_path: output_rel_path,
      output_hash: Manifest.hash("generated"),
      spawns: [],
      module: nil
    }

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")

    Manifest.save(
      %{
        "disabled/one.txt|function|F_One|-" => record,
        "disabled/two.txt|function|F_Two|-" => %{record | output_path: "lib/nested/../shared.ex"}
      },
      manifest_path
    )

    write_main!(tmp_dir, "re", [])
    write_main!(tmp_dir, "pre-re", [])

    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == []
    refute File.exists?(output_path)
    assert Manifest.load(manifest_path) == %{}
  end

  @tag :tmp_dir
  test "authoritative reconciliation blocks active and stale aliases sharing one output", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "active"))

    File.write!(Path.join(npc_dir, "active/content.txt"), """
    prontera,100,100,4\tscript\tActive NPC\t54,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert first.failures == []
    assert [output_rel_path] = first.written
    output_path = Path.join(out_root, output_rel_path)

    active_key = "active/content.txt|script|Active NPC|prontera:100:100"
    stale_key = "disabled/stale.txt|script|Stale NPC|prontera:100:100"
    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    manifest = Manifest.load(manifest_path)
    active_record = manifest[active_key]

    stale_output_alias =
      Path.dirname(output_rel_path) <> "/nested/../" <> Path.basename(output_rel_path)

    stale_record = %{active_record | output_path: stale_output_alias}
    Manifest.save(Map.put(manifest, stale_key, stale_record), manifest_path)
    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)
    write_main!(tmp_dir, "re", ["active/content.txt"])
    write_main!(tmp_dir, "pre-re", ["active/content.txt"])

    result = Transpiler.run(tmp_dir, out_root: out_root)

    assert result.failures == [
             {:stale, "disabled/stale.txt", 0,
              {:output_owned_by_active, output_rel_path, ["active/content.txt"]}}
           ]

    assert result.written == []
    assert File.exists?(output_path)
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "a manifest key keeps its suffixed output after a stale reservation is removed", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))
    File.mkdir_p!(Path.join(npc_dir, "active"))

    File.write!(Path.join(npc_dir, "disabled/helper.txt"), """
    function\tscript\tF_Stable\t{
    return 0;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert [reserved_rel_path] = first.written
    reserved_path = Path.join(out_root, reserved_rel_path)

    active_source = Path.join(npc_dir, "active/helper.txt")

    File.write!(active_source, """
    function\tscript\tF_Stable\t{
    return 1;
    }
    """)

    write_main!(tmp_dir, "re", ["active/helper.txt"])
    write_main!(tmp_dir, "pre-re", ["active/helper.txt"])

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.failures == []
    assert second.conflicts == []
    assert [stable_rel_path] = second.written
    assert stable_rel_path != reserved_rel_path
    assert String.ends_with?(stable_rel_path, "/f_stable_0.ex")
    refute File.exists?(reserved_path)

    stable_path = Path.join(out_root, stable_rel_path)
    assert File.exists?(stable_path)

    third = Transpiler.run(tmp_dir, out_root: out_root)

    assert third.failures == []
    assert third.conflicts == []
    assert third.written == []
    assert third.skipped == 1
    assert File.exists?(stable_path)

    File.write!(active_source, """
    function\tscript\tF_Stable\t{
    return 2;
    }
    """)

    fourth = Transpiler.run(tmp_dir, out_root: out_root)

    assert fourth.failures == []
    assert fourth.conflicts == []
    assert fourth.written == [stable_rel_path]
    assert File.read!(stable_path) =~ "{ctx, 2}"
    refute File.exists?(reserved_path)

    fifth = Transpiler.run(tmp_dir, out_root: out_root, force: true)

    assert fifth.failures == []
    assert fifth.conflicts == []
    assert fifth.written == [stable_rel_path]
    assert File.exists?(stable_path)
  end

  @tag :tmp_dir
  test "only runs never prune records or outputs outside the selected sources", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))
    File.mkdir_p!(Path.join(npc_dir, "active"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert [stale_rel_path] = first.written
    stale_path = Path.join(out_root, stale_rel_path)

    File.write!(Path.join(npc_dir, "active/content.txt"), """
    prontera,100,100,4\tscript\tActive NPC\t54,{
    close;
    }
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root, only: "active/**")

    assert second.failures == []
    assert [_active_rel_path] = second.written
    assert File.exists?(stale_path)

    manifest = Manifest.load(Path.join(out_root, "priv/npc_transpile/manifest.json"))
    assert Map.has_key?(manifest, "disabled/content.txt|floating|::StaleBody|-")
    assert Map.has_key?(manifest, "active/content.txt|script|Active NPC|prontera:100:100")
  end

  @tag :tmp_dir
  test "structural linking failures leave untouched stale outputs and records intact", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert [stale_rel_path] = first.written
    stale_path = Path.join(out_root, stale_rel_path)

    File.write!(Path.join(npc_dir, "shared.txt"), """
    -\tscript\t::AmbiguousGuard\t-1,{
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/source.txt"), """
    -\tscript\t::AmbiguousGuard\t-1,{
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,70,70,4\tduplicate(AmbiguousGuard)\tAmbiguous Placement\t54
    """)

    write_main!(tmp_dir, "re", ["shared.txt", "re/source.txt", "re/duplicate.txt"])
    write_main!(tmp_dir, "pre-re", ["shared.txt"])

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert [
             {:link, "re/duplicate.txt", 1,
              {:ambiguous_duplicate, "AmbiguousGuard", :renewal, _candidates}}
           ] = second.failures

    assert second.written == []
    assert File.exists?(stale_path)
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "edited stale outputs block authoritative runs before unrelated writes", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    function\tscript\tF_Stale\t{
    return 1;
    }
    function\tscript\tF_Stale_2\t{
    return 2;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert length(first.written) == 3

    [untouched_rel_path | edited_rel_paths] = Enum.sort(first.written)
    untouched = {untouched_rel_path, File.read!(Path.join(out_root, untouched_rel_path))}

    edited =
      Map.new(edited_rel_paths, fn rel_path ->
        path = Path.join(out_root, rel_path)
        content = File.read!(path) <> "# hand edit\n"
        File.write!(path, content)
        {rel_path, content}
      end)

    File.write!(Path.join(npc_dir, "active.txt"), """
    prontera,100,100,4\tscript\tActive NPC\t54,{
    close;
    }
    """)

    write_main!(tmp_dir, "re", ["active.txt"])
    write_main!(tmp_dir, "pre-re", ["active.txt"])

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)

    second = Transpiler.run(tmp_dir, out_root: out_root)

    expected_failures =
      edited
      |> Map.keys()
      |> Enum.map(&{:stale, "disabled/content.txt", 0, {:output_modified, &1}})
      |> Enum.sort()

    assert Enum.sort(second.failures) == expected_failures
    assert second.written == []

    Enum.each([untouched | Map.to_list(edited)], fn {rel_path, content} ->
      assert File.read!(Path.join(out_root, rel_path)) == content
    end)

    active_output =
      Path.join(out_root, "lib/aesir/zone_server/content/npc/active/active_npc.ex")

    refute File.exists?(active_output)
    assert File.read!(manifest_path) == manifest_before
  end

  @tag :tmp_dir
  test "a stale remove failure persists active writes and remains retryable", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    function\tscript\tF_Stale\t{
    return 1;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert length(first.written) == 2

    stale_rel_path = Enum.find(first.written, &String.contains?(&1, "/floating/"))
    removable_rel_path = Enum.find(first.written, &String.contains?(&1, "/functions/"))
    stale_path = Path.join(out_root, stale_rel_path)
    removable_path = Path.join(out_root, removable_rel_path)
    stale_dir = Path.dirname(stale_path)

    File.write!(Path.join(npc_dir, "active.txt"), """
    prontera,100,100,4\tscript\tActive NPC\t54,{
    close;
    }
    """)

    write_main!(tmp_dir, "re", ["active.txt"])
    write_main!(tmp_dir, "pre-re", ["active.txt"])

    on_exit(fn ->
      if File.exists?(stale_dir), do: File.chmod!(stale_dir, 0o700)
    end)

    File.chmod!(stale_dir, 0o500)
    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert [
             {:stale, "disabled/content.txt", 0, {:output_remove_failed, ^stale_rel_path, reason}}
           ] = second.failures

    assert reason in [:eacces, :eperm]
    assert [active_rel_path] = second.written
    assert second.conflicts == []
    assert File.exists?(stale_path)
    refute File.exists?(removable_path)
    assert File.exists?(Path.join(out_root, active_rel_path))

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    manifest = Manifest.load(manifest_path)
    assert Map.has_key?(manifest, "disabled/content.txt|floating|::StaleBody|-")
    refute Map.has_key?(manifest, "disabled/content.txt|function|F_Stale|-")
    assert Map.has_key?(manifest, "active.txt|script|Active NPC|prontera:100:100")

    File.chmod!(stale_dir, 0o700)
    third = Transpiler.run(tmp_dir, out_root: out_root)

    assert third.failures == []
    assert third.conflicts == []
    assert third.written == []
    assert third.skipped == 1
    refute File.exists?(stale_path)

    reconciled_manifest = Manifest.load(manifest_path)
    refute Map.has_key?(reconciled_manifest, "disabled/content.txt|floating|::StaleBody|-")
    refute Map.has_key?(reconciled_manifest, "disabled/content.txt|function|F_Stale|-")
    assert Map.has_key?(reconciled_manifest, "active.txt|script|Active NPC|prontera:100:100")
  end

  @tag :tmp_dir
  test "authoritative runs drop stale records whose outputs are already missing", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "disabled"))

    File.write!(Path.join(npc_dir, "disabled/content.txt"), """
    -\tscript\t::StaleBody\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "disabled/**")

    assert first.failures == []
    assert [stale_rel_path] = first.written

    stale_path = Path.join(out_root, stale_rel_path)
    File.rm!(stale_path)
    write_main!(tmp_dir, "re", [])
    write_main!(tmp_dir, "pre-re", [])

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.failures == []
    assert second.written == []
    refute File.exists?(stale_path)

    manifest = Manifest.load(Path.join(out_root, "priv/npc_transpile/manifest.json"))
    refute Map.has_key?(manifest, "disabled/content.txt|floating|::StaleBody|-")
  end

  @tag :tmp_dir
  test "a shared caller regenerates only when its literal helper targets change", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "shared/caller.txt"), """
    prontera,100,100,4\tscript\tShared Caller\t54,{
    callfunc "F_Mode";
    close;
    }
    """)

    write_main!(tmp_dir, "re", ["shared/caller.txt"])
    write_main!(tmp_dir, "pre-re", ["shared/caller.txt"])

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root)

    assert first.failures == []
    assert [caller_path] = first.written
    assert File.read!(Path.join(out_root, caller_path)) =~ ~S|todo(:callfunc, ["F_Mode"])|

    File.write!(Path.join(npc_dir, "re/helpers.txt"), """
    function\tscript\tF_Mode\t{
    return 1;
    }
    """)

    write_main!(tmp_dir, "re", ["shared/caller.txt", "re/helpers.txt"])

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.failures == []
    assert caller_path in second.written
    caller = File.read!(Path.join(out_root, caller_path))
    assert caller =~ "case GameMode.mode() do"
    assert caller =~ "Aesir.ZoneServer.Content.Npc.Re.Functions.FMode.call"

    File.write!(Path.join(npc_dir, "re/unrelated.txt"), """
    function\tscript\tF_Unrelated\t{
    return 2;
    }
    """)

    write_main!(tmp_dir, "re", ["shared/caller.txt", "re/helpers.txt", "re/unrelated.txt"])

    third = Transpiler.run(tmp_dir, out_root: out_root)

    assert third.failures == []
    refute caller_path in third.written
    assert File.read!(Path.join(out_root, caller_path)) == caller
  end

  @tag :tmp_dir
  test "a mode caller regenerates when its active helper becomes disabled", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "re"))

    File.write!(Path.join(npc_dir, "re/caller.txt"), """
    izlude,100,100,4\tscript\tRenewal Caller\t54,{
    callfunc "F_Active";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/helper.txt"), """
    function\tscript\tF_Active\t{
    return 1;
    }
    """)

    write_main!(tmp_dir, "re", ["re/caller.txt", "re/helper.txt"])
    write_main!(tmp_dir, "pre-re", [])

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root)

    assert first.failures == []
    caller_path = Enum.find(first.written, &String.ends_with?(&1, "/renewal_caller.ex"))

    assert File.read!(Path.join(out_root, caller_path)) =~
             "Aesir.ZoneServer.Content.Npc.Re.Functions.FActive.call"

    write_main!(tmp_dir, "re", ["re/caller.txt"])

    second = Transpiler.run(tmp_dir, out_root: out_root)

    assert second.failures == []
    assert caller_path in second.written
    caller = File.read!(Path.join(out_root, caller_path))
    assert caller =~ ~S|todo(:callfunc, ["F_Active"])|
    refute caller =~ "Functions.FActive.call"
  end

  @tag :tmp_dir
  test "incompatible helper links fail before any output or manifest write", %{tmp_dir: tmp_dir} do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "re"))
    File.mkdir_p!(Path.join(npc_dir, "pre-re"))

    File.write!(Path.join(npc_dir, "re/caller.txt"), """
    izlude,100,100,4\tscript\tRenewal Caller\t54,{
    callfunc "F_Pre";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "pre-re/caller.txt"), """
    morocc,100,100,4\tscript\tClassic Caller\t54,{
    callfunc "F_Re";
    close;
    }
    """)

    File.write!(Path.join(npc_dir, "re/helper.txt"), """
    function\tscript\tF_Re\t{
    return 1;
    }
    """)

    File.write!(Path.join(npc_dir, "pre-re/helper.txt"), """
    function\tscript\tF_Pre\t{
    return 2;
    }
    """)

    write_main!(tmp_dir, "re", ["re/caller.txt", "re/helper.txt"])
    write_main!(tmp_dir, "pre-re", ["pre-re/caller.txt", "pre-re/helper.txt"])

    expected_failures =
      Enum.sort([
        {:link, "re/caller.txt", 1, {:incompatible_helper, "F_Pre", :renewal, [:pre_renewal]}},
        {:link, "pre-re/caller.txt", 1, {:incompatible_helper, "F_Re", :pre_renewal, [:renewal]}}
      ])

    existing_out = Path.join(tmp_dir, "existing_out")
    manifest_path = Path.join(existing_out, "priv/npc_transpile/manifest.json")

    Manifest.save(
      %{
        "disabled.txt|floating|::Existing|-" => %{
          source_hash: "source",
          output_path: "lib/existing.ex",
          output_hash: "output",
          spawns: [],
          module: nil
        }
      },
      manifest_path
    )

    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)

    existing = Transpiler.run(tmp_dir, out_root: existing_out)

    assert Enum.sort(existing.failures) == expected_failures
    assert existing.written == []
    assert Path.wildcard(Path.join(existing_out, "lib/**/*.ex")) == []
    assert File.read!(manifest_path) == manifest_before

    absent_out = Path.join(tmp_dir, "absent_out")
    absent = Transpiler.run(tmp_dir, out_root: absent_out)

    assert Enum.sort(absent.failures) == expected_failures
    assert absent.written == []
    assert Path.wildcard(Path.join(absent_out, "lib/**/*.ex")) == []
    refute File.exists?(Path.join(absent_out, "priv/npc_transpile/manifest.json"))
  end

  @tag :tmp_dir
  test "a cross-run duplicate fails loudly when its manifest source cannot be recovered", %{
    tmp_dir: tmp_dir
  } do
    npc_dir = Path.join(tmp_dir, "npc")
    File.mkdir_p!(Path.join(npc_dir, "shared"))
    File.mkdir_p!(Path.join(npc_dir, "re"))

    shared_path = Path.join(npc_dir, "shared/guard.txt")

    File.write!(shared_path, """
    -\tscript\t::GuardFloat\t-1,{
    close;
    }
    """)

    out_root = Path.join(tmp_dir, "out")
    first = Transpiler.run(tmp_dir, out_root: out_root, only: "shared/**")

    assert first.failures == []
    assert [_source_path] = first.written

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    File.write!(manifest_path, File.read!(manifest_path) <> "\n")
    manifest_before = File.read!(manifest_path)
    File.rm!(shared_path)

    File.write!(Path.join(npc_dir, "re/duplicate.txt"), """
    izlude,100,100,4\tduplicate(GuardFloat)\tRenewal Guard\t54
    """)

    second = Transpiler.run(tmp_dir, out_root: out_root, only: "re/**")

    key = "shared/guard.txt|floating|::GuardFloat|-"

    assert second.failures == [
             {:link, "shared/guard.txt", 0,
              {:unrecoverable_duplicate_source, key, :shared, :source_unavailable}}
           ]

    assert second.written == []
    assert second.orphan_duplicates == []
    assert File.read!(manifest_path) == manifest_before
  end
end
