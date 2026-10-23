defmodule Mix.Tasks.Aesir.Import.SkillNocastTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.SkillNocast

  test "ORs every line of a skill into one mask and skips comments" do
    lines = [
      "// header\n",
      "26,4\t//AL_TELEPORT\n",
      "27,8\n",
      "26,512\n",
      "\n",
      "26,4\n"
    ]

    assert SkillNocast.to_rows(lines) == [
             %{"id" => 26, "flags" => 516},
             %{"id" => 27, "flags" => 8}
           ]
  end
end
