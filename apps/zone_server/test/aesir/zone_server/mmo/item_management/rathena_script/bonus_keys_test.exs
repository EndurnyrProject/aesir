defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeysTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.BonusKeys
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

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
    :max_hp,
    :max_sp,
    :max_hp_rate,
    :max_sp_rate,
    :aspd,
    :aspd_rate,
    :all_stats,
    :atk_rate,
    :matk_rate,
    :varcast_rate,
    :delay_rate,
    :long_atk_rate,
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
    :unbreakable_shoes,
    :hp_regen,
    :sp_regen,
    :sp_cost_rate,
    :perfect_dodge,
    :movement_speed,
    :fixed_cast,
    :heal_power,
    :crit_atk_rate,
    :short_atk_rate,
    :perfect_hit,
    :splash_range,
    :hp_drain_rate,
    :hp_drain_percent
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
      assert BonusKeys.destination("bNoRegen") == :error
    end

    test "resolves the splash range key case-insensitively" do
      assert BonusKeys.destination("bSplashRange") == {:ok, :splash_range}
      assert BonusKeys.destination("bsplashrange") == {:ok, :splash_range}
    end

    test "resolves the regen and sp-economy keys case-insensitively" do
      assert BonusKeys.destination("bHPrecovRate") == {:ok, :hp_regen}
      assert BonusKeys.destination("bhprecovrate") == {:ok, :hp_regen}
      assert BonusKeys.destination("bSPrecovRate") == {:ok, :sp_regen}
      assert BonusKeys.destination("bUseSPrate") == {:ok, :sp_cost_rate}
    end

    test "resolves the dodge, speed, fixed-cast and heal-power keys" do
      assert BonusKeys.destination("bFlee2") == {:ok, :perfect_dodge}
      assert BonusKeys.destination("bSpeedRate") == {:ok, :movement_speed}
      assert BonusKeys.destination("bFixedCast") == {:ok, :fixed_cast}
      assert BonusKeys.destination("bHealPower") == {:ok, :heal_power}
    end

    test "resolves the capacity, rate and all-stats keys" do
      assert BonusKeys.destination("bMaxHP") == {:ok, :max_hp}
      assert BonusKeys.destination("bMaxSP") == {:ok, :max_sp}
      assert BonusKeys.destination("bMaxHPrate") == {:ok, :max_hp_rate}
      assert BonusKeys.destination("bMaxSPrate") == {:ok, :max_sp_rate}
      assert BonusKeys.destination("bAspd") == {:ok, :aspd}
      assert BonusKeys.destination("bAspdRate") == {:ok, :aspd_rate}
      assert BonusKeys.destination("bAllStats") == {:ok, :all_stats}
      assert BonusKeys.destination("bAtkRate") == {:ok, :atk_rate}
      assert BonusKeys.destination("bMatkRate") == {:ok, :matk_rate}
    end

    test "bAtkEle is a value key, not a numeric destination" do
      assert BonusKeys.destination("bAtkEle") == :error
      assert BonusKeys.value_schema("bAtkEle") == {:ok, %{dest: :atk_ele, param: :element}}
      assert BonusKeys.value_param(:atk_ele) == {:ok, :element}
      assert BonusKeys.value_destinations() == [:atk_ele]
    end

    test "value_schema/1 returns :error for the numeric keys" do
      assert BonusKeys.value_schema("bStr") == :error
      assert BonusKeys.value_param(:str) == :error
    end

    test "resolves the cast, delay and long-attack rate keys" do
      assert BonusKeys.destination("bVariableCastrate") == {:ok, :varcast_rate}
      assert BonusKeys.destination("bDelayrate") == {:ok, :delay_rate}
      assert BonusKeys.destination("bLongAtkRate") == {:ok, :long_atk_rate}
    end

    test "resolves the damage-side rate keys" do
      assert BonusKeys.destination("bCritAtkRate") == {:ok, :crit_atk_rate}
      assert BonusKeys.destination("bShortAtkRate") == {:ok, :short_atk_rate}
      assert BonusKeys.destination("bPerfectHitAddRate") == {:ok, :perfect_hit}
    end

    test "bCritAtkRate is a destination of its own, never the trait crit rate" do
      assert BonusKeys.destination("bCritAtkRate") == {:ok, :crit_atk_rate}
      assert BonusKeys.destination("bCritical") == {:ok, :critical}
      assert BonusKeys.destination("bCrt") == {:ok, :crt}
    end

    test "bVariableCastrate resolves independently in the flat and bonus2 tables" do
      assert BonusKeys.destination("bVariableCastrate") == {:ok, :varcast_rate}

      assert BonusKeys.param_schema("bVariableCastrate") ==
               {:ok, %{family: :skill_varcast_rate, param: :skill, unit: :percent}}
    end
  end

  describe "max_destination?/1" do
    test "movement speed does not stack" do
      assert BonusKeys.max_destination?(:movement_speed)
    end

    test "splash range does not stack" do
      assert BonusKeys.max_destination?(:splash_range)
    end

    test "ordinary destinations stack" do
      refute BonusKeys.max_destination?(:atk)
      refute BonusKeys.max_destination?(:perfect_dodge)
      refute BonusKeys.max_destination?(:perfect_hit)
      refute BonusKeys.max_destination?(:crit_atk_rate)
      refute BonusKeys.max_destination?(:short_atk_rate)
      refute BonusKeys.max_destination?(:hp_drain_rate)
      refute BonusKeys.max_destination?(:hp_drain_percent)
      refute BonusKeys.max_destination?({:skill_use_sp_rate, 28})
    end
  end

  describe "destination_scale/1" do
    test "perfect dodge is scaled to per-mille units" do
      assert BonusKeys.destination_scale(:perfect_dodge) == 10
    end

    test "unscaled destinations report a factor of 1" do
      assert BonusKeys.destination_scale(:atk) == 1
      assert BonusKeys.destination_scale(:movement_speed) == 1
      assert BonusKeys.destination_scale(:perfect_hit) == 1
      assert BonusKeys.destination_scale(:crit_atk_rate) == 1
      assert BonusKeys.destination_scale(:short_atk_rate) == 1
      assert BonusKeys.destination_scale(:splash_range) == 1
      assert BonusKeys.destination_scale(:hp_drain_rate) == 1
      assert BonusKeys.destination_scale(:hp_drain_percent) == 1
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
    "bexpaddrace" => %{family: :exp_add_race, param: :race, unit: :percent},
    "bignoredefracerate" => %{family: :ignore_def_race, param: :race, unit: :percent},
    "bignoremdefracerate" => %{family: :ignore_mdef_race, param: :race, unit: :percent},
    "bskillcooldown" => %{family: :skill_cooldown, param: :skill, unit: :ms},
    "bskillusesp" => %{family: :skill_use_sp, param: :skill, unit: :sp},
    "bvariablecastrate" => %{family: :skill_varcast_rate, param: :skill, unit: :percent},
    "bskillusesprate" => %{family: :skill_use_sp_rate, param: :skill, unit: :percent},
    "baddeff" => %{family: :add_eff, param: :status, unit: :per10k},
    "baddeffwhenhit" => %{family: :add_eff_when_hit, param: :status, unit: :per10k},
    "breseff" => %{family: :res_eff, param: :status, unit: :per10k}
  }

  describe "param_schema/1" do
    test "resolves every documented bonus2 parameterized key" do
      for {key, schema} <- @param_schemas do
        assert BonusKeys.param_schema(key) == {:ok, schema}
      end
    end

    test "resolves case-insensitively" do
      assert BonusKeys.param_schema("bExpAddRace") == {:ok, @param_schemas["bexpaddrace"]}
      assert BonusKeys.param_schema("bAddRace") == {:ok, @param_schemas["baddrace"]}
      assert BonusKeys.param_schema("BADDRACE") == {:ok, @param_schemas["baddrace"]}
    end

    test "resolves the skill-economy keys case-insensitively" do
      assert BonusKeys.param_schema("bSkillCooldown") == {:ok, @param_schemas["bskillcooldown"]}
      assert BonusKeys.param_schema("bSkillUseSP") == {:ok, @param_schemas["bskillusesp"]}

      assert BonusKeys.param_schema("bSkillUseSPrate") ==
               {:ok, @param_schemas["bskillusesprate"]}

      assert BonusKeys.param_schema("bVariableCastrate") ==
               {:ok, @param_schemas["bvariablecastrate"]}
    end

    test "returns :error for not-yet-supported bonus2 keys" do
      assert BonusKeys.param_schema("bautospell") == :error
    end

    test "resolves the status infliction/resist keys case-insensitively" do
      assert BonusKeys.param_schema("bAddEff") == {:ok, @param_schemas["baddeff"]}
      assert BonusKeys.param_schema("bAddEffWhenHit") == {:ok, @param_schemas["baddeffwhenhit"]}
      assert BonusKeys.param_schema("bResEff") == {:ok, @param_schemas["breseff"]}
    end

    test "returns :error for flat keys" do
      assert BonusKeys.param_schema("bstr") == :error
    end
  end

  describe "pair_schema/1" do
    test "resolves the HP drain key case-insensitively" do
      expected = {:ok, %{first: :hp_drain_rate, second: :hp_drain_percent}}

      assert BonusKeys.pair_schema("bHPDrainRate") == expected
      assert BonusKeys.pair_schema("bhpdrainrate") == expected
      assert BonusKeys.pair_schema("BHPDRAINRATE") == expected
    end

    test "returns :error for parameterized and flat keys" do
      assert BonusKeys.pair_schema("bAddRace") == :error
      assert BonusKeys.pair_schema("bStr") == :error
    end

    test "both pair halves are ordinary summing destinations" do
      assert :hp_drain_rate in BonusKeys.destinations()
      assert :hp_drain_percent in BonusKeys.destinations()
      assert BonusKeys.param_schema("bHPDrainRate") == :error
      assert BonusKeys.destination("bHPDrainRate") == :error
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

    test "status domain equals the Resolver effs value set" do
      expected = Resolver.effs() |> Map.values() |> Enum.uniq()

      assert Enum.sort(BonusKeys.param_domain(:status)) == Enum.sort(expected)
    end
  end
end
