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
end
