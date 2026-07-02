defmodule Aesir.ZoneServer.Npc.Transpiler.ManifestTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.Manifest

  @record %{source_hash: "src1", output_path: "a.ex", output_hash: "out1"}

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

  test "loading a missing file yields an empty manifest" do
    assert Manifest.load("/nonexistent/manifest.json") == %{}
  end
end
