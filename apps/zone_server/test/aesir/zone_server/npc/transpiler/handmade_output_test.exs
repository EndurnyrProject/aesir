defmodule Aesir.ZoneServer.Npc.Transpiler.HandmadeOutputTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler

  @tag :tmp_dir
  test "source changes and forced imports preserve hand-edited output and its original manifest",
       %{
         tmp_dir: tmp_dir
       } do
    source_path = Path.join(tmp_dir, "npc/pre-re/guide.txt")
    File.mkdir_p!(Path.dirname(source_path))

    source = """
    prontera,100,100,4\tscript\tGuide\t105,{
    mes "Welcome";
    close;
    }
    """

    File.write!(source_path, source)
    out_root = Path.join(tmp_dir, "out")
    opts = [out_root: out_root, only: "pre-re/guide.txt"]
    initial = Transpiler.run(tmp_dir, opts)

    assert initial.failures == []
    assert initial.conflicts == []
    assert [output] = initial.written

    output_path = Path.join(out_root, output)
    handwritten = String.replace(File.read!(output_path), "Welcome", "A hand-written greeting")
    File.write!(output_path, handwritten)

    manifest_path = Path.join(out_root, "priv/npc_transpile/manifest.json")
    manifest = File.read!(manifest_path)
    unchanged = Transpiler.run(tmp_dir, opts)

    assert unchanged.skipped == 1
    assert unchanged.written == []
    assert File.read!(output_path) == handwritten

    for {upstream, force?} <- [
          {source, true},
          {String.replace(source, "Welcome", "Hello"), false}
        ] do
      File.write!(source_path, upstream)
      result = Transpiler.run(tmp_dir, Keyword.put(opts, :force, force?))

      assert result.failures == []
      assert result.written == []
      assert [{^output, conflict}] = result.conflicts
      assert conflict =~ "/_conflicts/"
      assert File.exists?(Path.join(out_root, conflict))
      assert File.read!(output_path) == handwritten
      assert File.read!(manifest_path) == manifest
    end
  end
end
