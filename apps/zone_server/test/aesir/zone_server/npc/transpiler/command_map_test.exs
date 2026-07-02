defmodule Aesir.ZoneServer.Npc.Transpiler.CommandMapTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.CommandMap
  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

  test "known commands return their rule, unknown return :error" do
    assert {:ok, %{dsl: "give_item", args: [:item, :int]}} = CommandMap.command("getitem")
    assert {:ok, %{shape: :warp}} = CommandMap.command("warp")
    assert :error = CommandMap.command("getpartymember")
  end

  test "reads and call reads" do
    assert {:ok, "base_level"} = CommandMap.read("BaseLevel")
    assert {:ok, %{dsl: "count_item"}} = CommandMap.call_read("countitem")
    assert :error = CommandMap.read("PartnerId")
  end

  test "supported? covers commands and call reads" do
    assert CommandMap.supported?("getitem")
    assert CommandMap.supported?("countitem")
    refute CommandMap.supported?("getmapxy")
  end

  test "warp special targets" do
    assert {:ok, ":random"} = CommandMap.warp_target("Random")
    assert {:ok, ":save_point"} = CommandMap.warp_target("SavePoint")
    assert :error = CommandMap.warp_target("prontera")
  end

  describe "Resolver" do
    test "constants resolve booleans and curated symbol maps" do
      assert {:ok, "1"} = Resolver.constant("true")
      assert {:ok, ":thief"} = Resolver.constant("Job_Thief")
      assert {:ok, ":sc_blessing"} = Resolver.constant("SC_BLESSING")
      assert :error = Resolver.constant("bc_self")
    end

    test "loads the sprite table from an e_job_types enum" do
      hpp = """
      enum e_job_types
      {
      \tNPC_RANGE1_START = 44,
      \tJT_WARPNPC,
      \tJT_1_ETC_01,
      \tJT_HIDDEN_WARP_NPC = 139, // comment
      \tJT_4_ELDER = 10205,
      \tJT_FAKENPC = -1
      };
      """

      path = Path.join(System.tmp_dir!(), "npc_test.hpp")
      File.write!(path, hpp)
      on_exit(fn -> File.rm(path) end)

      assert {:ok, sprites} = Resolver.load_sprites(path)

      assert sprites["WARPNPC"] == 45
      assert sprites["1_ETC_01"] == 46
      assert sprites["HIDDEN_WARP_NPC"] == 139
      assert sprites["4_ELDER"] == 10_205
      assert sprites["FAKENPC"] == -1
      refute Map.has_key?(sprites, "NPC_RANGE1_START")
    end
  end
end
