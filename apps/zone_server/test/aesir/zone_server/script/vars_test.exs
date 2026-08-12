defmodule Aesir.ZoneServer.Script.VarsTest do
  @moduledoc """
  Covers the runtime variable-name parser behind rAthena `getd`/`setd`: scope
  sigil recognition and trailing `[N]` array index stripping.
  """

  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Script.Vars

  describe "parse_name/1" do
    test "server permanent ($): key drops the sigil, keeps the string marker" do
      assert Vars.parse_name("$donate") == {:server, "donate", nil}
      assert Vars.parse_name("$ma_name03$") == {:server, "ma_name03$", nil}
    end

    test "server temp ($@) wins over the $ prefix" do
      assert Vars.parse_name("$@stage") == {:server_temp, "stage", nil}
      assert Vars.parse_name("$@gqse_miro") == {:server_temp, "gqse_miro", nil}
    end

    test "account scopes keep the sigil in the key" do
      assert Vars.parse_name("#points") == {:account, "#points", nil}
      assert Vars.parse_name("##points") == {:account_global, "##points", nil}
      assert Vars.parse_name("##name$") == {:account_global, "##name$", nil}
    end

    test "npc (.) and local (.@) scopes" do
      assert Vars.parse_name(".counter") == {:npc, "counter", nil}
      assert Vars.parse_name(".@msg$") == {:local, "msg$", nil}
      assert Vars.parse_name(".@mob_1") == {:local, "mob_1", nil}
    end

    test "temp (@) and bare char names" do
      assert Vars.parse_name("@buffs") == {:temp, "buffs", nil}
      assert Vars.parse_name("ep13_3_quest_done") == {:char, "ep13_3_quest_done", nil}
      assert Vars.parse_name("Mission_1") == {:char, "Mission_1", nil}
    end

    test "instance scope (' )" do
      assert Vars.parse_name("'box_a") == {:instance, "box_a", nil}
      assert Vars.parse_name("'xy_3$") == {:instance, "xy_3$", nil}
    end

    test "strips a trailing [N] array element" do
      assert Vars.parse_name("$arr[2]") == {:server, "arr", 2}
      assert Vars.parse_name("$arr[0]") == {:server, "arr", 0}
      assert Vars.parse_name(".@mob$[1]") == {:local, "mob$", 1}
      assert Vars.parse_name("$@queue[5]") == {:server_temp, "queue", 5}
    end

    test "a malformed or empty index defaults to element 0" do
      assert Vars.parse_name("$arr[abc]") == {:server, "arr", 0}
      assert Vars.parse_name("$arr[]") == {:server, "arr", 0}
    end

    test "an empty name parses as a bare char var" do
      assert Vars.parse_name("") == {:char, "", nil}
    end
  end
end
