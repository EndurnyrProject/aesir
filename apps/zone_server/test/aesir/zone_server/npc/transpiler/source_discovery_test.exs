defmodule Aesir.ZoneServer.Npc.Transpiler.SourceDiscoveryTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.SourceDiscovery

  @tag :tmp_dir
  test "discovers sources from both mode roots in declaration order", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "npc: npc/re/re.txt\n")
    write!(root, "npc/pre-re/scripts_main.conf", "npc: npc/pre-re/pre.txt\n")
    write!(root, "npc/re/re.txt")
    write!(root, "npc/pre-re/pre.txt")

    assert SourceDiscovery.discover!(root) == [
             source(root, "re/re.txt", :renewal),
             source(root, "pre-re/pre.txt", :pre_renewal)
           ]
  end

  @tag :tmp_dir
  test "follows nested imports depth-first and deduplicates first-seen sources", %{tmp_dir: root} do
    write!(
      root,
      "npc/re/scripts_main.conf",
      """
      npc: npc/shared/first.txt
      import: npc/config/one.conf
      npc: npc/re/last.txt
      """
    )

    write!(
      root,
      "npc/config/one.conf",
      """
      npc: npc/shared/middle.txt
      import: npc/config/two.conf
      """
    )

    write!(root, "npc/config/two.conf", "npc: npc/re/nested.txt\n")

    write!(
      root,
      "npc/pre-re/scripts_main.conf",
      """
      npc: npc/shared/first.txt
      npc: npc/pre-re/overlay.txt
      """
    )

    for relative <- [
          "shared/first.txt",
          "shared/middle.txt",
          "re/nested.txt",
          "re/last.txt",
          "pre-re/overlay.txt"
        ] do
      write!(root, Path.join("npc", relative))
    end

    assert SourceDiscovery.discover!(root) == [
             source(root, "shared/first.txt", :shared),
             source(root, "shared/middle.txt", :shared),
             source(root, "re/nested.txt", :renewal),
             source(root, "re/last.txt", :renewal),
             source(root, "pre-re/overlay.txt", :pre_renewal)
           ]
  end

  @tag :tmp_dir
  test "strips comments before matching active directives", %{tmp_dir: root} do
    write!(
      root,
      "npc/re/scripts_main.conf",
      """
      // npc: npc/shared/disabled.txt
      import: npc/config/enabled.conf // trailing comment
      """
    )

    write!(root, "npc/config/enabled.conf", "npc: npc/shared/enabled.txt // keep this\n")
    write!(root, "npc/pre-re/scripts_main.conf", "// import: npc/config/disabled.conf\n")
    write!(root, "npc/shared/enabled.txt")

    assert SourceDiscovery.discover!(root) == [source(root, "shared/enabled.txt", :shared)]
  end

  @tag :tmp_dir
  test "rejects a malformed active import directive", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "import: npc/config/one.conf extra\n")
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error, ~r/malformed import directive.*npc\/re\/scripts_main\.conf:1/, fn ->
      SourceDiscovery.discover!(root)
    end
  end

  @tag :tmp_dir
  test "rejects a malformed active npc directive", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "npc:\n")
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error, ~r/malformed npc directive.*npc\/re\/scripts_main\.conf:1/, fn ->
      SourceDiscovery.discover!(root)
    end
  end

  @tag :tmp_dir
  test "reports a missing imported config with its include chain", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "import: npc/config/one.conf\n")
    write!(root, "npc/config/one.conf", "import: npc/config/missing.conf\n")
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error,
                 ~r/missing config npc\/config\/missing\.conf referenced by npc\/config\/one\.conf:1.*include chain: npc\/re\/scripts_main\.conf -> npc\/config\/one\.conf -> npc\/config\/missing\.conf/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "reports a missing terminal source with its referring config and include chain", %{
    tmp_dir: root
  } do
    write!(root, "npc/re/scripts_main.conf", "import: npc/config/one.conf\n")
    write!(root, "npc/config/one.conf", "npc: npc/shared/missing.txt\n")
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error,
                 ~r/missing NPC source npc\/shared\/missing\.txt referenced by npc\/config\/one\.conf:1.*include chain: npc\/re\/scripts_main\.conf -> npc\/config\/one\.conf/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "reports config cycles with the complete include chain", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "import: npc/config/one.conf\n")
    write!(root, "npc/config/one.conf", "import: npc/config/two.conf\n")
    write!(root, "npc/config/two.conf", "import: npc/config/one.conf\n")
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error,
                 ~r/config cycle.*npc\/config\/two\.conf:1.*npc\/re\/scripts_main\.conf -> npc\/config\/one\.conf -> npc\/config\/two\.conf -> npc\/config\/one\.conf/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "rejects imported config paths that escape the checkout", %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "checkout")
    write!(root, "npc/re/scripts_main.conf", "import: ../outside.conf\n")
    write!(root, "npc/pre-re/scripts_main.conf")
    write!(tmp_dir, "outside.conf")

    assert_raise Mix.Error,
                 ~r/config path \.\.\/outside\.conf escapes rAthena root.*npc\/re\/scripts_main\.conf:1.*include chain: npc\/re\/scripts_main\.conf -> \.\.\/outside\.conf/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "deduplicates terminal symlink aliases by canonical first-seen identity", %{tmp_dir: root} do
    write!(
      root,
      "npc/re/scripts_main.conf",
      """
      npc: npc/re/alias.txt
      npc: npc/shared/real.txt
      """
    )

    write!(root, "npc/pre-re/scripts_main.conf")
    real = write!(root, "npc/shared/real.txt")
    link!(real, Path.join(root, "npc/re/alias.txt"))

    assert SourceDiscovery.discover!(root) == [source(root, "re/alias.txt", :renewal)]
  end

  @tag :tmp_dir
  test "detects a config cycle through an in-checkout symlink alias", %{tmp_dir: root} do
    write!(root, "npc/re/scripts_main.conf", "import: npc/config/one.conf\n")
    real = write!(root, "npc/config/one.conf", "import: npc/config/alias.conf\n")
    link!(real, Path.join(root, "npc/config/alias.conf"))
    write!(root, "npc/pre-re/scripts_main.conf")

    assert_raise Mix.Error,
                 ~r/config cycle.*npc\/config\/one\.conf -> npc\/config\/alias\.conf/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "rejects imported config symlinks that resolve outside the checkout", %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "checkout")
    write!(root, "npc/re/scripts_main.conf", "import: npc/re/external.conf\n")
    write!(root, "npc/pre-re/scripts_main.conf")
    outside = write!(tmp_dir, "outside.conf")
    link!(outside, Path.join(root, "npc/re/external.conf"))

    assert_raise Mix.Error,
                 ~r/config path npc\/re\/external\.conf resolves outside canonical rAthena root.*npc\/re\/scripts_main\.conf:1/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "rejects terminal source symlinks that resolve outside the checkout", %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "checkout")
    write!(root, "npc/re/scripts_main.conf", "npc: npc/shared/external.txt\n")
    write!(root, "npc/pre-re/scripts_main.conf")
    outside = write!(tmp_dir, "outside.txt")
    link!(outside, Path.join(root, "npc/shared/external.txt"))

    assert_raise Mix.Error,
                 ~r/NPC source path npc\/shared\/external\.txt resolves outside canonical rAthena root.*npc\/re\/scripts_main\.conf:1/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "rejects only matches that resolve through symlinks outside the checkout", %{
    tmp_dir: tmp_dir
  } do
    root = Path.join(tmp_dir, "checkout")
    outside = write!(tmp_dir, "outside.txt")
    link!(outside, Path.join(root, "npc/shared/external.txt"))

    assert_raise Mix.Error,
                 ~r/NPC source path .*external\.txt resolves outside canonical rAthena root/,
                 fn -> SourceDiscovery.discover!(root, only: "shared/external.txt") end
  end

  @tag :tmp_dir
  test "rejects a broken in-checkout symlink selected by only", %{tmp_dir: root} do
    link!("missing.txt", Path.join(root, "npc/shared/broken.txt"))

    assert_raise Mix.Error,
                 ~r/only match npc\/shared\/broken\.txt is not a regular file/,
                 fn -> SourceDiscovery.discover!(root, only: "shared/broken.txt") end
  end

  @tag :tmp_dir
  test "rejects a matching directory selected by only", %{tmp_dir: root} do
    File.mkdir_p!(Path.join(root, "npc/shared/directory.txt"))

    assert_raise Mix.Error,
                 ~r/only match npc\/shared\/directory\.txt is not a regular file/,
                 fn -> SourceDiscovery.discover!(root, only: "shared/directory.txt") end
  end

  @tag :tmp_dir
  test "rejects terminal source paths that escape the checkout", %{tmp_dir: tmp_dir} do
    root = Path.join(tmp_dir, "checkout")
    write!(root, "npc/re/scripts_main.conf", "npc: ../outside.txt\n")
    write!(root, "npc/pre-re/scripts_main.conf")
    write!(tmp_dir, "outside.txt")

    assert_raise Mix.Error,
                 ~r/NPC source path \.\.\/outside\.txt escapes rAthena root.*npc\/re\/scripts_main\.conf:1.*include chain: npc\/re\/scripts_main\.conf -> \.\.\/outside\.txt/s,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "reports a missing main config with root include context", %{tmp_dir: root} do
    assert_raise Mix.Error,
                 ~r/missing config npc\/re\/scripts_main\.conf; include chain: npc\/re\/scripts_main\.conf/,
                 fn -> SourceDiscovery.discover!(root) end
  end

  @tag :tmp_dir
  test "only globs select disabled files relative to npc without reading configs", %{
    tmp_dir: root
  } do
    write!(root, "npc/re/disabled.txt")
    write!(root, "npc/pre-re/disabled.txt")
    write!(root, "npc/shared/other.txt")

    assert SourceDiscovery.discover!(root, only: "**/disabled.txt") == [
             source(root, "pre-re/disabled.txt", :pre_renewal),
             source(root, "re/disabled.txt", :renewal)
           ]
  end

  defp write!(root, relative, content \\ "") do
    path = Path.join(root, relative)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
    path
  end

  defp link!(target, path) do
    File.mkdir_p!(Path.dirname(path))
    File.ln_s!(target, path)
  end

  defp source(root, relative, scope) do
    %{path: Path.join([root, "npc", relative]), relative: relative, scope: scope}
  end
end
