defmodule Aesir.ZoneServer.Npc.Transpiler.ManifestTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Manifest

  @record %{
    source_hash: "src1",
    output_path: "a.ex",
    output_hash: "out1",
    spawns: [],
    module: "Aesir.ZoneServer.Content.Npc.Functions.Test"
  }

  test "decision table covers all regen situations" do
    # new entry
    assert Manifest.decide(nil, "src1", :missing) == :write
    # new entry colliding with a hand-written module
    assert Manifest.decide(nil, "src1", {:present, "whatever"}) == :conflict
    # source unchanged: skip, regardless of what happened to the output
    assert Manifest.decide(@record, "src1", {:present, "out1"}) == :skip
    assert Manifest.decide(@record, "src1", {:present, "edited"}) == :skip
    assert Manifest.decide(@record, "src1", :missing) == :skip
    # source changed, output untouched: regenerate in place
    assert Manifest.decide(@record, "src2", {:present, "out1"}) == :write
    # source changed, output hand-edited or moved: conflict
    assert Manifest.decide(@record, "src2", {:present, "edited"}) == :conflict
    assert Manifest.decide(@record, "src2", :missing) == :conflict
  end

  test "round-trips allowlisted placement scopes as JSON strings" do
    path =
      Path.join(System.tmp_dir!(), "manifest_test_#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(path) end)

    spawns = [
      %{map: "prontera", x: 1, y: 2, dir: 0, sprite: 46, name: "Shared", scope: :shared},
      %{
        map: "payon",
        x: 3,
        y: 4,
        dir: 2,
        sprite: 47,
        name: "Renewal",
        scope: :renewal,
        trigger: {1, 2}
      },
      %{
        map: "geffen",
        x: 5,
        y: 6,
        dir: 4,
        sprite: 48,
        name: "Classic",
        scope: :pre_renewal
      }
    ]

    manifest = %{"npc/test.txt|script|Scoped|prontera:1:2" => %{@record | spawns: spawns}}

    Manifest.save(manifest, path)

    serialized_scopes =
      path
      |> File.read!()
      |> Jason.decode!()
      |> get_in(["npc/test.txt|script|Scoped|prontera:1:2", "spawns"])
      |> Enum.map(& &1["scope"])

    assert serialized_scopes == ["shared", "renewal", "pre_renewal"]
    assert Manifest.load(path) == manifest
  end

  test "legacy spawns inherit body scope from their record key" do
    path =
      Path.join(System.tmp_dir!(), "manifest_test_#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(path) end)

    spawn = %{map: "prontera", x: 1, y: 2, dir: 0, sprite: 46, name: "Legacy"}

    legacy = %{
      "npc/shared.txt|script|Shared|prontera:1:2" => %{@record | spawns: [spawn, spawn]},
      "re/npc.txt|floating|::Renewal|-" => %{@record | spawns: [spawn]},
      "pre-re/npc.txt|script|Classic|prontera:1:2" => %{@record | spawns: [spawn]}
    }

    File.write!(path, Jason.encode!(legacy))
    loaded = Manifest.load(path)

    assert Enum.map(loaded["npc/shared.txt|script|Shared|prontera:1:2"].spawns, & &1.scope) == [
             :shared,
             :shared
           ]

    assert hd(loaded["re/npc.txt|floating|::Renewal|-"].spawns).scope == :renewal
    assert hd(loaded["pre-re/npc.txt|script|Classic|prontera:1:2"].spawns).scope == :pre_renewal
  end

  test "rejects an unknown serialized scope without creating an atom" do
    path =
      Path.join(System.tmp_dir!(), "manifest_test_#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(path) end)

    unknown = "unknown_#{System.unique_integer([:positive])}"
    spawn = %{map: "prontera", x: 1, y: 2, dir: 0, sprite: 46, name: "Invalid", scope: unknown}
    manifest = %{"npc/test.txt|script|Invalid|prontera:1:2" => %{@record | spawns: [spawn]}}

    File.write!(path, Jason.encode!(manifest))

    message = ~r/unknown NPC manifest placement scope #{Regex.escape(inspect(unknown))}/
    assert_raise ArgumentError, message, fn -> Manifest.load(path) end

    assert_raise ArgumentError, fn -> String.to_existing_atom(unknown) end
  end

  test "rejects an explicit null serialized scope" do
    path =
      Path.join(System.tmp_dir!(), "manifest_test_#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(path) end)

    spawn = %{map: "prontera", x: 1, y: 2, dir: 0, sprite: 46, name: "Invalid", scope: nil}
    manifest = %{"npc/test.txt|script|Invalid|prontera:1:2" => %{@record | spawns: [spawn]}}

    File.write!(path, Jason.encode!(manifest))

    assert_raise ArgumentError, ~r/unknown NPC manifest placement scope nil/, fn ->
      Manifest.load(path)
    end
  end

  test "round-trips deterministically" do
    path =
      Path.join(System.tmp_dir!(), "manifest_test_#{System.unique_integer([:positive])}.json")

    on_exit(fn -> File.rm(path) end)

    manifest = %{
      "b|script|Npc B|payon:1:2" => @record,
      "a|script|Npc A|prontera:3:4" => %{@record | output_path: "b.ex"}
    }

    Manifest.save(manifest, path)
    assert Manifest.load(path) == manifest

    first = File.read!(path)
    Manifest.save(manifest, path)
    assert File.read!(path) == first
  end

  test "keys distinguish placements, hash is stable" do
    placed = %{file: "f.txt", kind: :script, name: "Guard", map: "payon", x: 1, y: 2}
    floating = %{file: "f.txt", kind: :floating, name: "Guard"}

    assert Manifest.key(placed) == "f.txt|script|Guard|payon:1:2"
    assert Manifest.key(floating) == "f.txt|floating|Guard|-"
    assert Manifest.hash("abc") == Manifest.hash("abc")
    refute Manifest.hash("abc") == Manifest.hash("abd")
  end

  test "derives source file and body scope from every manifest record kind" do
    records = [
      {"cities/prontera.txt|script|Guard|prontera:1:2", "cities/prontera.txt", :shared},
      {"re/jobs/3-1/guillotine_cross.txt|floating|::Helper|-", "re/jobs/3-1/guillotine_cross.txt",
       :renewal},
      {"pre-re/jobs/2-1/knight.txt|function|F_Classic|-", "pre-re/jobs/2-1/knight.txt",
       :pre_renewal}
    ]

    for {key, file, scope} <- records do
      assert Manifest.source_file(key) == file
      assert Manifest.body_scope(key) == scope
    end
  end

  test "loading a missing file yields an empty manifest" do
    assert Manifest.load("/nonexistent/manifest.json") == %{}
  end
end
