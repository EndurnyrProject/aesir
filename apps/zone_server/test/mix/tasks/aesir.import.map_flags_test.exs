defmodule Mix.Tasks.Aesir.Import.MapFlagsTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Aesir.Import.MapFlags, as: Task

  defp rows(lines), do: lines |> Task.replay() |> Task.to_rows()

  test "replays the setter rules and writes everything but pvp" do
    lines = [
      "// comment\n",
      "arena\tmapflag\tpvp\n",
      "arena\tmapflag\tgvg\n",
      "bg\tmapflag\tgvg_dungeon\n",
      "bg\tmapflag\tbattleground\t2\n",
      "castle\tmapflag\tgvg_te_castle\n",
      "castle\tmapflag\tgvg_castle\n",
      "dun\tmapflag\tgvg_dungeon\n",
      "dun\tmapflag\tpvp\n",
      "nogvg\tmapflag\tgvg\n",
      "nogvg\tmapflag\tgvg\toff\n"
    ]

    assert rows(lines) == [
             %{"map" => "arena", "flags" => ["gvg"]},
             %{"map" => "bg", "flags" => ["battleground"]},
             %{"map" => "castle", "flags" => ["gvg_castle"]}
           ]
  end

  test "the skill-restriction flags set only themselves and an off line clears them" do
    lines = [
      "arena\tmapflag\tpvp\n",
      "arena\tmapflag\tnoteleport\n",
      "arena\tmapflag\tnoskill\n",
      "field\tmapflag\tnowarp\n",
      "field\tmapflag\tnoicewall\n",
      "field\tmapflag\tnoicewall\toff\n"
    ]

    assert rows(lines) == [
             %{"map" => "arena", "flags" => ["noskill", "noteleport"]},
             %{"map" => "field", "flags" => ["nowarp"]}
           ]
  end

  test "restricted zones add bit 1 << (n + 4), an off line clears them and a bare one is skipped" do
    lines = [
      "jail\tmapflag\trestricted\t1\n",
      "jail\tmapflag\trestricted\t3\n",
      "jail\tmapflag\trestricted\n",
      "freed\tmapflag\trestricted\t2\n",
      "freed\tmapflag\trestricted\toff\n"
    ]

    assert rows(lines) == [%{"map" => "jail", "flags" => [], "zone" => 32 + 128}]
  end
end
