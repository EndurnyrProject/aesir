defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeysTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys

  @documented_destinations [
    :str,
    :agi,
    :vit,
    :int,
    :dex,
    :luk,
    :pow,
    :sta,
    :wis,
    :spl,
    :con,
    :crt,
    :atk,
    :matk,
    :def,
    :mdef,
    :hit,
    :flee,
    :critical,
    :patk,
    :smatk,
    :res,
    :mres,
    :break_weapon_rate,
    :break_armor_rate,
    :unbreakable,
    :unbreakable_weapon,
    :unbreakable_armor,
    :unbreakable_helm,
    :unbreakable_shield,
    :unbreakable_garment,
    :unbreakable_shoes
  ]

  describe "destination/1" do
    test "resolves the classic stat keys" do
      assert BonusKeys.destination("bStr") == {:ok, :str}
      assert BonusKeys.destination("bLuk") == {:ok, :luk}
    end

    test "resolves the base trait keys" do
      assert BonusKeys.destination("bPow") == {:ok, :pow}
      assert BonusKeys.destination("bCrt") == {:ok, :crt}
    end

    test "resolves the combat trait keys case-insensitively" do
      assert BonusKeys.destination("bPAtk") == {:ok, :patk}
      assert BonusKeys.destination("bPatk") == {:ok, :patk}
      assert BonusKeys.destination("BPATK") == {:ok, :patk}
    end

    test "bBaseAtk and bAtk both map to :atk" do
      assert BonusKeys.destination("bBaseAtk") == {:ok, :atk}
      assert BonusKeys.destination("bAtk") == {:ok, :atk}
    end

    test "resolves the classic combat keys" do
      assert BonusKeys.destination("bMatk") == {:ok, :matk}
      assert BonusKeys.destination("bDef") == {:ok, :def}
      assert BonusKeys.destination("bMdef") == {:ok, :mdef}
      assert BonusKeys.destination("bHit") == {:ok, :hit}
      assert BonusKeys.destination("bFlee") == {:ok, :flee}
      assert BonusKeys.destination("bCritical") == {:ok, :critical}
    end

    test "resolves the break-rate keys case-insensitively" do
      assert BonusKeys.destination("bBreakWeaponRate") == {:ok, :break_weapon_rate}
      assert BonusKeys.destination("bbreakweaponrate") == {:ok, :break_weapon_rate}
      assert BonusKeys.destination("bBreakArmorRate") == {:ok, :break_armor_rate}
    end

    test "resolves the unbreakable keys, general and per-slot" do
      assert BonusKeys.destination("bUnbreakable") == {:ok, :unbreakable}
      assert BonusKeys.destination("bUnbreakableWeapon") == {:ok, :unbreakable_weapon}
      assert BonusKeys.destination("bUnbreakableArmor") == {:ok, :unbreakable_armor}
      assert BonusKeys.destination("bUnbreakableHelm") == {:ok, :unbreakable_helm}
      assert BonusKeys.destination("bUnbreakableShield") == {:ok, :unbreakable_shield}
      assert BonusKeys.destination("bUnbreakableGarment") == {:ok, :unbreakable_garment}
      assert BonusKeys.destination("bUnbreakableShoes") == {:ok, :unbreakable_shoes}
    end

    test "returns :error for an out-of-vocabulary key" do
      assert BonusKeys.destination("bMaxHP") == :error
    end
  end

  describe "destinations/0" do
    test "returns exactly the documented section-3 destination set" do
      assert Enum.sort(Enum.uniq(BonusKeys.destinations())) ==
               Enum.sort(Enum.uniq(@documented_destinations))
    end
  end

  @param_schemas %{
    "baddrace" => %{family: :addrace, param: :race, unit: :percent},
    "baddele" => %{family: :addele, param: :element, unit: :percent},
    "baddsize" => %{family: :addsize, param: :size, unit: :percent},
    "baddclass" => %{family: :addclass, param: :class, unit: :percent},
    "bsubrace" => %{family: :subrace, param: :race, unit: :percent},
    "bsubele" => %{family: :subele, param: :element, unit: :percent},
    "bsubsize" => %{family: :subsize, param: :size, unit: :percent},
    "bsubclass" => %{family: :subclass, param: :class, unit: :percent},
    "bmagicaddrace" => %{family: :magic_addrace, param: :race, unit: :percent},
    "bmagicaddele" => %{family: :magic_addele, param: :element, unit: :percent},
    "bmagicaddsize" => %{family: :magic_addsize, param: :size, unit: :percent},
    "bmagicatkele" => %{family: :magic_atk_ele, param: :element, unit: :percent},
    "bskillatk" => %{family: :skill_atk, param: :skill, unit: :percent},
    "bignoredefracerate" => %{family: :ignore_def_race, param: :race, unit: :percent},
    "bignoremdefracerate" => %{family: :ignore_mdef_race, param: :race, unit: :percent}
  }

  describe "param_schema/1" do
    test "resolves every documented bonus2 damage-tier key" do
      for {key, schema} <- @param_schemas do
        assert BonusKeys.param_schema(key) == {:ok, schema}
      end
    end

    test "resolves case-insensitively" do
      assert BonusKeys.param_schema("bAddRace") == {:ok, @param_schemas["baddrace"]}
      assert BonusKeys.param_schema("BADDRACE") == {:ok, @param_schemas["baddrace"]}
    end

    test "returns :error for not-yet-supported bonus2 keys" do
      assert BonusKeys.param_schema("bskillcooldown") == :error
      assert BonusKeys.param_schema("baddeff") == :error
    end

    test "returns :error for flat keys" do
      assert BonusKeys.param_schema("bstr") == :error
    end
  end

  describe "families/0" do
    test "returns exactly the documented param-key families" do
      expected = @param_schemas |> Map.values() |> Enum.map(& &1.family) |> Enum.uniq()

      assert Enum.sort(BonusKeys.families()) == Enum.sort(expected)
    end
  end

  describe "family_param/1" do
    test "resolves every documented param-key family to its param kind" do
      for schema <- Map.values(@param_schemas) do
        assert BonusKeys.family_param(schema.family) == {:ok, schema.param}
      end
    end

    test "returns :error for a family outside the vocabulary" do
      assert BonusKeys.family_param(:bogus_family) == :error
    end
  end

  describe "param_domain/1" do
    test "race domain" do
      assert BonusKeys.param_domain(:race) == [
               :formless,
               :undead,
               :brute,
               :plant,
               :insect,
               :fish,
               :demon,
               :demi_human,
               :angel,
               :dragon,
               :player_human,
               :all
             ]
    end

    test "element domain" do
      assert BonusKeys.param_domain(:element) == [
               :neutral,
               :water,
               :earth,
               :fire,
               :wind,
               :poison,
               :holy,
               :shadow,
               :ghost,
               :undead,
               :all
             ]
    end

    test "size domain" do
      assert BonusKeys.param_domain(:size) == [:small, :medium, :large, :all]
    end

    test "class domain" do
      assert BonusKeys.param_domain(:class) == [:normal, :boss, :all]
    end
  end
end
