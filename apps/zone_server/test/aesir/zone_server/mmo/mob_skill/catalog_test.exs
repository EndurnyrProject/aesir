defmodule Aesir.ZoneServer.Mmo.MobSkill.CatalogTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.MobSkill.Catalog

  describe "archetype_for/1 - elemental nukes" do
    test "maps NPC attribute attacks to :elemental_nuke by element" do
      assert Catalog.archetype_for("NPC_FIREATTACK") == {:elemental_nuke, %{element: :fire}}
      assert Catalog.archetype_for("NPC_WATERATTACK") == {:elemental_nuke, %{element: :water}}
      assert Catalog.archetype_for("NPC_WINDATTACK") == {:elemental_nuke, %{element: :wind}}
      assert Catalog.archetype_for("NPC_HOLYATTACK") == {:elemental_nuke, %{element: :holy}}
      assert Catalog.archetype_for("NPC_UNDEADATTACK") == {:elemental_nuke, %{element: :undead}}
      assert Catalog.archetype_for("NPC_DARKSTRIKE") == {:elemental_nuke, %{element: :shadow}}
      assert Catalog.archetype_for("NPC_DARKNESSATTACK") == {:elemental_nuke, %{element: :shadow}}
    end

    test "maps mage/wizard single-target bolts to :elemental_nuke" do
      assert Catalog.archetype_for("MG_FIREBOLT") == {:elemental_nuke, %{element: :fire}}
      assert Catalog.archetype_for("MG_COLDBOLT") == {:elemental_nuke, %{element: :water}}
      assert Catalog.archetype_for("MG_LIGHTNINGBOLT") == {:elemental_nuke, %{element: :wind}}
      assert Catalog.archetype_for("MG_FIREBALL") == {:elemental_nuke, %{element: :fire}}
      assert Catalog.archetype_for("MG_SOULSTRIKE") == {:elemental_nuke, %{element: :ghost}}
      assert Catalog.archetype_for("MG_NAPALMBEAT") == {:elemental_nuke, %{element: :ghost}}
      assert Catalog.archetype_for("WZ_JUPITEL") == {:elemental_nuke, %{element: :wind}}
      assert Catalog.archetype_for("WZ_WATERBALL") == {:elemental_nuke, %{element: :water}}
    end
  end

  describe "archetype_for/1 - status attacks" do
    test "NPC_STUNATTACK inflicts :sc_stun" do
      assert Catalog.archetype_for("NPC_STUNATTACK") ==
               {:status_attack, %{element: :neutral, status: :sc_stun}}
    end

    test "maps the remaining status attacks with element and status" do
      assert Catalog.archetype_for("NPC_POISON") ==
               {:status_attack, %{element: :neutral, status: :sc_poison}}

      assert Catalog.archetype_for("NPC_POISONATTACK") ==
               {:status_attack, %{element: :poison, status: :sc_poison}}

      assert Catalog.archetype_for("NPC_BLINDATTACK") ==
               {:status_attack, %{element: :neutral, status: :sc_blind}}

      assert Catalog.archetype_for("NPC_CURSEATTACK") ==
               {:status_attack, %{element: :shadow, status: :sc_curse}}

      assert Catalog.archetype_for("NPC_SILENCEATTACK") ==
               {:status_attack, %{element: :neutral, status: :sc_silence}}

      assert Catalog.archetype_for("NPC_SLEEPATTACK") ==
               {:status_attack, %{element: :neutral, status: :sc_sleep}}

      assert Catalog.archetype_for("MG_FROSTDIVER") ==
               {:status_attack, %{element: :water, status: :sc_freeze}}

      assert Catalog.archetype_for("NPC_BLEEDING") ==
               {:status_attack, %{element: :neutral, status: :sc_bleeding}}
    end
  end

  describe "archetype_for/1 - ground nukes" do
    test "maps AoE skills to :ground_nuke with element and area" do
      assert Catalog.archetype_for("WZ_METEOR") ==
               {:ground_nuke, %{element: :fire, area: :around}}

      assert Catalog.archetype_for("WZ_STORMGUST") ==
               {:ground_nuke, %{element: :water, area: :around}}

      assert Catalog.archetype_for("WZ_HEAVENDRIVE") ==
               {:ground_nuke, %{element: :earth, area: :around}}

      assert Catalog.archetype_for("WZ_VERMILION") ==
               {:ground_nuke, %{element: :wind, area: :around}}

      assert Catalog.archetype_for("MG_THUNDERSTORM") ==
               {:ground_nuke, %{element: :wind, area: :around}}

      assert Catalog.archetype_for("NPC_EARTHQUAKE") ==
               {:ground_nuke, %{element: :neutral, area: :around}}

      assert Catalog.archetype_for("NPC_GROUNDATTACK") ==
               {:ground_nuke, %{element: :earth, area: :around}}
    end
  end

  describe "archetype_for/1 - heal, summon, teleport" do
    test "maps heals to :heal" do
      assert Catalog.archetype_for("AL_HEAL") == {:heal, %{}}
      assert Catalog.archetype_for("NPC_ALLHEAL") == {:heal, %{}}
    end

    test "maps summons to :summon_slave" do
      assert Catalog.archetype_for("NPC_SUMMONSLAVE") == {:summon_slave, %{}}
      assert Catalog.archetype_for("NPC_CALLSLAVE") == {:summon_slave, %{}}
    end

    test "maps AL_TELEPORT to :teleport" do
      assert Catalog.archetype_for("AL_TELEPORT") == {:teleport, %{}}
    end
  end

  describe "archetype_for/1 - dispel and ground fields" do
    test "maps SA_DISPELL to :dispel" do
      assert Catalog.archetype_for("SA_DISPELL") == {:dispel, %{}}
    end

    test "maps SA_LANDPROTECTOR to the ground-field dispatch of the real skill module" do
      assert Catalog.archetype_for("SA_LANDPROTECTOR") ==
               {:ground_field, %{skill_name: :sa_landprotector}}
    end
  end

  describe "archetype_for/1 - self buffs" do
    test "maps self-buffs with a matching status module to :self_buff" do
      assert Catalog.archetype_for("NPC_AGIUP") ==
               {:self_buff, %{status: :sc_increaseagi}}

      assert Catalog.archetype_for("SM_ENDURE") ==
               {:self_buff, %{status: :sc_endure}}
    end

    test "leaves self-buffs without a matching status module stubbed" do
      assert Catalog.archetype_for("NPC_POWERUP") == :stub
      assert Catalog.archetype_for("CR_AUTOGUARD") == :stub
      assert Catalog.archetype_for("NPC_STONESKIN") == :stub
      assert Catalog.archetype_for("NPC_DEFENDER") == :stub
    end
  end

  describe "archetype_for/1 - stubs" do
    test "neutral physical melee and cosmetic skills stub out" do
      assert Catalog.archetype_for("NPC_EMOTION") == :stub
      assert Catalog.archetype_for("NPC_CRITICALSLASH") == :stub
      assert Catalog.archetype_for("NPC_COMBOATTACK") == :stub
      assert Catalog.archetype_for("NPC_PIERCINGATT") == :stub
      assert Catalog.archetype_for("NPC_SPLASHATTACK") == :stub
      assert Catalog.archetype_for("SM_BASH") == :stub
      assert Catalog.archetype_for("AS_SONICBLOW") == :stub
      assert Catalog.archetype_for("NPC_POWERUP") == :stub
      assert Catalog.archetype_for("CR_AUTOGUARD") == :stub
    end

    test "unknown/garbage keys stub out" do
      assert Catalog.archetype_for("NOT_A_REAL_SKILL") == :stub
      assert Catalog.archetype_for("") == :stub
    end
  end

  describe "catalog integrity" do
    @known_status_ids MapSet.new([
                        :sc_stun,
                        :sc_poison,
                        :sc_blind,
                        :sc_curse,
                        :sc_silence,
                        :sc_sleep,
                        :sc_freeze,
                        :sc_bleeding
                      ])

    test "every :status_attack status atom is a real status_effect id" do
      for {_skill, {:status_attack, %{status: status}}} <-
            Catalog.entries(),
          into: [] do
        assert MapSet.member?(@known_status_ids, status),
               "unexpected status atom #{inspect(status)} in catalog"
      end
    end

    test "every archetype is a built archetype module" do
      valid =
        MapSet.new([
          :elemental_nuke,
          :status_attack,
          :ground_nuke,
          :heal,
          :summon_slave,
          :teleport,
          :self_buff,
          :dispel,
          :ground_field
        ])

      for {_skill, {archetype, params}} <- Catalog.entries() do
        assert MapSet.member?(valid, archetype)
        assert is_map(params)
      end
    end

    @valid_elements MapSet.new([
                      :neutral,
                      :water,
                      :earth,
                      :fire,
                      :wind,
                      :poison,
                      :holy,
                      :shadow,
                      :ghost,
                      :undead
                    ])

    test "every element param is a real Combat.ElementModifiers element (never :dark)" do
      for {_skill, {_archetype, %{element: element}}} <- Catalog.entries() do
        assert MapSet.member?(@valid_elements, element),
               "unknown element #{inspect(element)} in catalog"
      end
    end
  end
end
