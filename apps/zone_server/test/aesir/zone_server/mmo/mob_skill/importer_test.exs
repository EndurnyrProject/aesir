defmodule Aesir.ZoneServer.Mmo.MobSkill.ImporterTest do
  use ExUnit.Case, async: true
  import Mimic

  alias Aesir.ZoneServer.Mmo.MobSkill.Denylist
  alias Aesir.ZoneServer.Mmo.MobSkill.Importer

  setup :verify_on_exit!

  @fixture """
  // Mob Skill Database fixture
  //
  1001,Scorpion@NPC_FIREATTACK,attack,186,1,2000,0,5000,yes,target,always,0,,,,,,,
  1001,Scorpion@NPC_POISON,attack,176,3,500,800,5000,no,target,always,0,,,,,,,
  1004,Hornet@NPC_WINDATTACK,attack,187,1,2000,0,5000,yes,target,always,0,,,,,,6,
  1063,Lunatic@NPC_EMOTION,idle,197,1,2000,0,5000,yes,self,always,0,1,0x81,,,,,
  1090,Marionette@NPC_HALLUCINATION,attack,195,1,500,0,5000,yes,target,mystatuson,hiding,,,,,,,
  -1,BossGlobal@NPC_SUMMONSLAVE,attack,196,1,10000,0,5000,no,self,slavele,3,1002,,,,,,
  -2,NormalGlobal@NPC_EMOTION,idle,197,1,2000,0,5000,yes,self,always,0,5,,,,,,
  -3,AllGlobal@AL_TELEPORT,walk,26,1,10000,0,5000,no,self,rudeattacked,0,,,,,,,
  """

  describe "to_rows/1 field parsing" do
    test "parses skill name from Info and scalar fields" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert [fire, poison] = rows["1001"]

      assert fire == %{
               skill: "NPC_FIREATTACK",
               skill_id: 186,
               state: :attack,
               level: 1,
               rate: 2000,
               cast_time: 0,
               delay: 5000,
               cancelable: true,
               target: :target,
               condition: %{
                 type: :always,
                 value: 0,
                 val1: nil,
                 val2: nil,
                 val3: nil,
                 val4: nil,
                 val5: nil
               },
               emotion: nil
             }

      assert poison.skill == "NPC_POISON"
      assert poison.skill_id == 176
      assert poison.level == 3
      assert poison.rate == 500
      assert poison.cast_time == 800
      assert poison.cancelable == false
    end

    test "parses emotion when present" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert [%{emotion: 6, skill: "NPC_WINDATTACK"}] = rows["1004"]
    end

    test "parses C-style hex val fields (mode bitmask on NPC_EMOTION)" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert [%{condition: %{val1: 1, val2: 0x81}}] = rows["1063"]
    end

    test "keeps a status-name condition value as an atom" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert [%{condition: %{type: :mystatuson, value: :hiding}}] = rows["1090"]
    end

    test "keeps condition value and val fields" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert [%{condition: condition}] = rows["global_boss"]

      assert condition == %{
               type: :slavele,
               value: 3,
               val1: 1002,
               val2: nil,
               val3: nil,
               val4: nil,
               val5: nil
             }
    end
  end

  describe "to_rows/1 grouping" do
    test "groups positive ids by string key and globals under reserved keys" do
      assert {:ok, rows} = Importer.to_rows(@fixture)
      assert Map.has_key?(rows, "1001")
      assert Map.has_key?(rows, "1004")
      assert [%{skill: "NPC_SUMMONSLAVE"}] = rows["global_boss"]
      assert [%{skill: "NPC_EMOTION"}] = rows["global_normal"]
      assert [%{skill: "AL_TELEPORT"}] = rows["global_all"]
    end
  end

  describe "to_rows/1 loud failure" do
    test "fails on an unknown state token" do
      line = "1001,Scorpion@NPC_POISON,flying,176,3,500,800,5000,no,target,always,0,,,,,,,"
      assert {:error, {:unknown_state, "flying"}} = Importer.to_rows(line)
    end

    test "fails on an unknown target token" do
      line = "1001,Scorpion@NPC_POISON,attack,176,3,500,800,5000,no,sideways,always,0,,,,,,,"
      assert {:error, {:unknown_target, "sideways"}} = Importer.to_rows(line)
    end

    test "fails on an unknown condition token" do
      line = "1001,Scorpion@NPC_POISON,attack,176,3,500,800,5000,no,target,wiggle,0,,,,,,,"
      assert {:error, {:unknown_condition, "wiggle"}} = Importer.to_rows(line)
    end
  end

  describe "classify/1" do
    # MG_FIREBOLT: a real player skill (id 19), resolvable in Skill.Catalog with
    # an active module, so it classifies as :castable by default.
    test "a skill id that resolves with an active module and is not denylisted is :castable" do
      stub(Denylist, :reason_for, fn 19 -> nil end)

      assert Importer.classify(19) == :castable
    end

    test "a skill id that resolves but is denylisted reports the reason" do
      stub(Denylist, :reason_for, fn 19 -> "no proto message" end)

      assert Importer.classify(19) == {:denylisted, "no proto message"}
    end

    test "a skill id with no catalog entry is :unresolved" do
      assert Importer.classify(999_999) == :unresolved
    end
  end
end
