defmodule Mix.Tasks.Aesir.Import.ItemNoequipTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.ItemNoequip, as: Task

  test "ORs flags in file order, clears with a negative flag and skips unknown items" do
    lines = [
      "// Forbidden Items\n",
      "519,322\t// Milk\n",
      "519,-2\n",
      "501,1\n",
      "501,-1\n",
      "999,4\n"
    ]

    assert Task.convert(lines, MapSet.new([501, 519])) ==
             {[%{"item" => 519, "flag" => 320}], [999]}
  end
end
