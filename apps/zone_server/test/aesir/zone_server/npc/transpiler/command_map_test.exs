defmodule Aesir.ZoneServer.Npc.Transpiler.CommandMapTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Npc.Transpiler.CommandMap
  alias Aesir.ZoneServer.Npc.Transpiler.Resolver

  test "known commands return their rule, unknown return :error" do
    assert {:ok, %{dsl: "give_item", args: [:item, :int]}} = CommandMap.command("getitem")

    assert {:ok, %{dsl: "get_named_item", args: [:item, :string]}} =
             CommandMap.command("getnameditem")

    assert {:ok, %{dsl: "give_item_bound", args: [:item, :int, :bound]}} =
             CommandMap.command("getitembound")

    assert {:ok, %{shape: :warp}} = CommandMap.command("warp")
    assert :error = CommandMap.command("getpartymember")
  end

  test "reads and call reads" do
    assert {:ok, "base_level"} = CommandMap.read("BaseLevel")
    assert {:ok, %{dsl: "count_item"}} = CommandMap.call_read("countitem")
    assert :error = CommandMap.read("PartnerId")
  end

  test "item-group buildins map statements and the optional read" do
    assert {:ok, %{dsl: "get_group_item", args: [:item_group]}} =
             CommandMap.command("getgroupitem")

    assert {:ok,
            %{shape: :item_group_optional, dsl: "get_rand_group_item", args: [:item_group, :int]}} =
             CommandMap.command("getrandgroupitem")

    assert {:ok, %{shape: :item_group_optional, dsl: "group_rand_item", args: [:item_group]}} =
             CommandMap.call_read("groupranditem")
  end

  test "skill maps to the permanent grant op; job lineage names are native reads" do
    assert {:ok, %{dsl: "skill", args: [:skill, :int, :int]}} = CommandMap.command("skill")
    assert CommandMap.supported?("skill")
    assert {:ok, "base_class"} = CommandMap.read("BaseClass")
    assert {:ok, "base_job"} = CommandMap.read("BaseJob")
    assert {:ok, ":permanent"} = Resolver.constant("SKILL_PERM")
  end

  test "npcskill maps to the npcskill DSL op" do
    assert {:ok, %{dsl: "npcskill", args: [:skill, :int, :int, :int]}} =
             CommandMap.command("npcskill")
  end

  test "skilleffect maps to the skilleffect DSL op" do
    assert {:ok, %{dsl: "skilleffect", args: [:skill, :int]}} =
             CommandMap.command("skilleffect")
  end

  test "setlook is a statement command and getlook is a call read, both with a look arg" do
    assert {:ok, %{dsl: "setlook", args: [:look, :int]}} = CommandMap.command("setlook")
    assert {:ok, %{dsl: "getlook", args: [:look]}} = CommandMap.call_read("getlook")
    assert CommandMap.supported?("setlook")
    assert CommandMap.supported?("GetLook")
  end

  test "supported? covers commands and call reads" do
    assert CommandMap.supported?("getitem")
    assert CommandMap.supported?("countitem")
    refute CommandMap.supported?("getmapxy")
  end

  test "event and session buildins map to ref1/opt1/timer shapes" do
    assert {:ok, %{shape: :ref1, dsl: "donpcevent"}} = CommandMap.command("donpcevent")
    assert {:ok, %{shape: :ref1, dsl: "doevent"}} = CommandMap.command("doevent")
    assert {:ok, %{shape: :ref1, dsl: "npctalk"}} = CommandMap.command("npctalk")
    assert {:ok, %{shape: :opt1, dsl: "enablenpc"}} = CommandMap.command("enablenpc")
    assert {:ok, %{shape: :opt1, dsl: "disablenpc"}} = CommandMap.command("disablenpc")
    assert {:ok, %{shape: :opt1, dsl: "hideonnpc"}} = CommandMap.command("hideonnpc")
    assert {:ok, %{shape: :opt1, dsl: "hideoffnpc"}} = CommandMap.command("hideoffnpc")
    assert {:ok, %{shape: :opt1, dsl: "cloakonnpc"}} = CommandMap.command("cloakonnpc")
    assert {:ok, %{shape: :opt1, dsl: "cloakonnpc"}} = CommandMap.command("cloakonnpcself")

    assert {:ok, %{shape: :opt1, dsl: "cloakoffnpcself"}} = CommandMap.command("cloakoffnpcself")

    assert {:ok, %{shape: :timer, dsl: "initnpctimer"}} = CommandMap.command("initnpctimer")
    assert {:ok, %{shape: :timer, dsl: "stopnpctimer"}} = CommandMap.command("stopnpctimer")
    assert CommandMap.supported?("hideoffnpc")
  end

  test "buildin lookups are case-insensitive like rAthena's engine" do
    assert {:ok, %{shape: :timer, dsl: "initnpctimer"}} = CommandMap.command("Initnpctimer")
    assert {:ok, %{dsl: "give_item"}} = CommandMap.command("GetItem")
    assert {:ok, %{dsl: "count_item"}} = CommandMap.call_read("CountItem")
    assert CommandMap.supported?("Monster")
    refute CommandMap.supported?("GetMapXY")
  end

  test "monster maps to the monster shape" do
    assert {:ok, %{shape: :monster}} = CommandMap.command("monster")
  end

  test "emotion maps to the emotion DSL op with an emote arg" do
    assert {:ok, %{dsl: "emotion", args: [:emote]}} = CommandMap.command("emotion")
  end

  test "specialeffect buildins map to their DSL ops with an effect arg" do
    assert {:ok, %{dsl: "specialeffect", args: [:effect]}} = CommandMap.command("specialeffect")
    assert {:ok, %{dsl: "specialeffect2", args: [:effect]}} = CommandMap.command("specialeffect2")
    assert CommandMap.supported?("specialeffect")
    assert CommandMap.supported?("SpecialEffect2")
  end

  test "consumeitem/nude/viewpoint/killmonster map to their DSL ops" do
    assert {:ok, %{dsl: "consumeitem", args: [:item]}} = CommandMap.command("consumeitem")
    assert {:ok, %{shape: :nullary, dsl: "nude"}} = CommandMap.command("nude")

    assert {:ok, %{dsl: "viewpoint", args: [:int, :int, :int, :int, :int]}} =
             CommandMap.command("viewpoint")

    assert {:ok, %{dsl: "killmonster", args: [:string, :string]}} =
             CommandMap.command("killmonster")

    assert CommandMap.supported?("consumeitem")
    assert CommandMap.supported?("Nude")
  end

  test "equipment reads map with equip-slot args" do
    assert {:ok, %{dsl: "getequipid", args: [:equip_slot]}} = CommandMap.call_read("getequipid")

    assert {:ok, %{dsl: "getequipcardid", args: [:equip_slot, :int]}} =
             CommandMap.call_read("getequipcardid")

    for {name, dsl} <- [
          {"getequipisequiped", "getequipisequiped"},
          {"getequiprefinerycnt", "getequiprefinerycnt"},
          {"getequipname", "getequipname"},
          {"getequipweaponlv", "getequipweaponlv"},
          {"getequiparmorlv", "getequiparmorlv"},
          {"getequipisenableref", "getequipisenableref"}
        ] do
      assert {:ok, %{dsl: ^dsl, args: [:equip_slot]}} = CommandMap.call_read(name)
      assert CommandMap.supported?(name)
    end

    assert {:ok, %{dsl: "getequippercentrefinery", args: [:equip_slot, :int]}} =
             CommandMap.call_read("getequippercentrefinery")

    assert {:ok, %{dsl: "getequiprefinecost", args: [:equip_slot, :int, :int]}} =
             CommandMap.call_read("getequiprefinecost")

    assert {:ok, %{dsl: "getiteminfo", args: [:item, :int]}} =
             CommandMap.call_read("getiteminfo")

    assert CommandMap.supported?("getequipisequiped")
    assert CommandMap.supported?("getequipid")
    assert CommandMap.supported?("getequipcardid")
    assert CommandMap.supported?("getiteminfo")
  end

  test "delequip and getitem2 map as statement commands" do
    assert {:ok, %{dsl: "delequip", args: [:equip_slot]}} = CommandMap.command("delequip")
    assert CommandMap.supported?("delequip")

    assert {:ok, %{dsl: "getitem2", args: args}} = CommandMap.command("getitem2")
    assert length(args) == 10
    assert CommandMap.supported?("getitem2")
  end

  test "successrefitem/failedrefitem/disable_items map as statement commands" do
    assert {:ok, %{dsl: "successrefitem", args: [:equip_slot, :int]}} =
             CommandMap.command("successrefitem")

    assert {:ok, %{dsl: "failedrefitem", args: [:equip_slot]}} =
             CommandMap.command("failedrefitem")

    assert {:ok, %{shape: :nullary, dsl: "disable_items"}} =
             CommandMap.command("disable_items")

    assert {:ok, %{shape: :nullary, dsl: "disable_items"}} =
             CommandMap.command("disableitemuse")

    for name <- ["successrefitem", "failedrefitem", "disable_items", "disableitemuse"] do
      assert CommandMap.supported?(name)
    end
  end

  test "F_GetNumSuffix maps to the num_suffix read function" do
    assert {:ok, %{kind: :read, dsl: "num_suffix"}} = CommandMap.function("F_GetNumSuffix")
  end

  test "broadcast buildins map to the announce shape" do
    assert {:ok, %{shape: :announce, dsl: "announce", fixed: 2}} = CommandMap.command("announce")

    assert {:ok, %{shape: :announce, dsl: "broadcast", fixed: 2}} =
             CommandMap.command("broadcast")

    assert {:ok, %{shape: :announce, dsl: "mapannounce", fixed: 3}} =
             CommandMap.command("mapannounce")

    assert {:ok, %{shape: :announce, dsl: "areaannounce", fixed: 7}} =
             CommandMap.command("areaannounce")

    assert CommandMap.supported?("announce")
  end

  test "warp special targets" do
    assert {:ok, ":random"} = CommandMap.warp_target("Random")
    assert {:ok, ":save_point"} = CommandMap.warp_target("SavePoint")
    assert :error = CommandMap.warp_target("prontera")
  end

  test "quest buildins map to their DSL ops" do
    assert {:ok, %{dsl: "setquest", args: [:int]}} = CommandMap.command("setquest")
    assert {:ok, %{dsl: "erasequest", args: [:int]}} = CommandMap.command("erasequest")
    assert {:ok, %{dsl: "completequest", args: [:int]}} = CommandMap.command("completequest")

    assert {:ok, %{dsl: "changequest", args: [:int, :int]}} =
             CommandMap.command("changequest")

    assert {:ok, %{dsl: "getexp", args: [:int, :int]}} = CommandMap.command("getexp")

    assert {:ok, %{dsl: "isbegin_quest", args: [:int]}} = CommandMap.call_read("isbegin_quest")

    assert {:ok, %{shape: :quest_check, dsl: "checkquest"}} =
             CommandMap.call_read("checkquest")

    assert {:ok, %{shape: :quest_check, dsl: "questprogress"}} =
             CommandMap.call_read("questprogress")

    for name <-
          ~w(setquest erasequest completequest changequest isbegin_quest checkquest questprogress) do
      assert CommandMap.supported?(name)
      assert CommandMap.supported?(String.upcase(name))
    end
  end

  test "Falcon buildins map as an effect and nullary call read" do
    assert {:ok, %{shape: :riding, dsl: "setfalcon"}} = CommandMap.command("setfalcon")
    assert {:ok, %{shape: :nullary, dsl: "checkfalcon"}} = CommandMap.call_read("checkfalcon")
    assert CommandMap.supported?("setfalcon")
    assert CommandMap.supported?("CheckFalcon")
  end

  test "setriding maps to the riding shape" do
    assert {:ok, %{shape: :riding, dsl: "set_riding"}} = CommandMap.command("setriding")
    assert CommandMap.supported?("setriding")
    assert CommandMap.supported?("SetRiding")
  end

  test "repair/repairall map to their DSL ops" do
    assert {:ok, %{dsl: "repair", args: [:int]}} = CommandMap.command("repair")
    assert {:ok, %{shape: :nullary, dsl: "repairall"}} = CommandMap.command("repairall")
    assert CommandMap.supported?("repair")
    assert CommandMap.supported?("RepairAll")
  end

  describe "Resolver" do
    test "constants resolve booleans and curated symbol maps" do
      assert {:ok, "1"} = Resolver.constant("true")
      assert {:ok, ":thief"} = Resolver.constant("Job_Thief")
      assert {:ok, ":sc_blessing"} = Resolver.constant("SC_BLESSING")
    end

    test "emote resolves ET_* tokens to Mmo.Emotion atoms, ints pass through" do
      assert {:ok, :money} = Resolver.emote("ET_MONEY")
      assert :error = Resolver.emote("ET_NOPE")
      assert {:ok, 42} = Resolver.emote(42)
    end

    test "effect resolves EF_* tokens to :ef_* atoms, ints pass through" do
      assert {:ok, :hit1} = Resolver.effect("EF_HIT1")
      assert :error = Resolver.effect("EF_NOPE")
      assert :error = Resolver.effect("NOT_AN_EFFECT")
      assert {:ok, 42} = Resolver.effect(42)
    end

    test "quest_mode resolves the HAVEQUEST/PLAYTIME/HUNTING constants" do
      assert {:ok, :havequest} = Resolver.quest_mode("HAVEQUEST")
      assert {:ok, :playtime} = Resolver.quest_mode("PLAYTIME")
      assert {:ok, :hunting} = Resolver.quest_mode("HUNTING")
      assert :error = Resolver.quest_mode("havequest")
      assert :error = Resolver.quest_mode("NOPE")
    end

    test "bound resolves supported bound constants" do
      assert {:ok, 1} = Resolver.bound("Bound_Account")
      assert {:ok, 4} = Resolver.bound("Bound_Char")
      assert :error = Resolver.bound("Bound_Guild")
      assert :error = Resolver.bound("Bound_Party")
    end

    test "equip_slot resolves EQI_* tokens to their ordinal, ints pass through" do
      assert {:ok, 0} = Resolver.equip_slot("EQI_ACC_L")
      assert {:ok, 6} = Resolver.equip_slot("EQI_HEAD_TOP")
      assert {:ok, 9} = Resolver.equip_slot("EQI_HAND_R")
      assert {:ok, 20} = Resolver.equip_slot("EQI_SHADOW_ACC_L")
      assert :error = Resolver.equip_slot("EQI_NOPE")
      assert {:ok, 3} = Resolver.equip_slot(3)
    end

    test "look resolves LOOK_* and VAR_* tokens to their enum ids, ints pass through" do
      assert {:ok, 1} = Resolver.look("LOOK_HAIR")
      assert {:ok, 3} = Resolver.look("LOOK_HEAD_BOTTOM")
      assert {:ok, 4} = Resolver.look("LOOK_HEAD_TOP")
      assert {:ok, 5} = Resolver.look("LOOK_HEAD_MID")
      assert {:ok, 6} = Resolver.look("LOOK_HAIR_COLOR")
      assert {:ok, 7} = Resolver.look("LOOK_CLOTHES_COLOR")
      assert {:ok, 12} = Resolver.look("LOOK_ROBE")
      assert {:ok, 13} = Resolver.look("LOOK_BODY2")
      assert {:ok, 1} = Resolver.look("VAR_HEAD")
      assert {:ok, 6} = Resolver.look("VAR_HEADPALETTE")
      assert {:ok, 7} = Resolver.look("VAR_BODYPALETTE")
      assert :error = Resolver.look("LOOK_NOPE")
      assert {:ok, 3} = Resolver.look(3)
    end

    test "broadcast flag constants resolve to their integer value" do
      assert {:ok, "3"} = Resolver.constant("bc_self")
      assert {:ok, "0"} = Resolver.constant("bc_all")
      assert {:ok, "16"} = Resolver.constant("bc_blue")
      assert :error = Resolver.constant("bc_nope")
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
