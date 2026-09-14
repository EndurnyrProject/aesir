defmodule Mix.Tasks.Aesir.ImportTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import

  test "parses the optional database mode" do
    assert Import.parse!(["/tmp/rathena"]) == {"/tmp/rathena", :renewal}
    assert Import.parse!(["--mode", "pre-re", "/tmp/rathena"]) == {"/tmp/rathena", :pre_renewal}
  end

  test "rejects an unsupported database mode" do
    assert_raise Mix.Error, ~r/expected re or pre-re/, fn ->
      Import.parse!(["--mode", "invalid"])
    end
  end

  @tag :tmp_dir
  test "ordered reads retain the normal parser's first duplicate key", %{tmp_dir: dir} do
    path = Path.join(dir, "db/item_db.yml")
    File.mkdir_p!(Path.dirname(path))

    File.write!(path, """
    Header:
      Type: ITEM_DB
      Version: 3
    Body:
      - Id: 1
        Trade:
          NoTrade: true
        Trade:
          NoDrop: true
        Jobs:
          Swordman: false
          All: true
    """)

    assert [[{"Id", 1}, {"Trade", [{"NoTrade", true}]}, {"Jobs", jobs}]] =
             Import.read_mode_filtered_ordered!(path, :renewal)

    assert jobs == [{"Swordman", false}, {"All", true}]
  end
end
