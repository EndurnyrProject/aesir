defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.BattleFlag
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  defp compile(script, context \\ :equip) do
    with {:ok, stmts} <- Parser.parse_body(script) do
      EquipCodegen.generate(stmts, context)
    end
  end

  # Builds the expected normalized flag from the axis names it should contain,
  # so the assertions read as the axes rather than as a magic number.
  defp skill_id!(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp battle_flag(names) do
    Enum.reduce(names, 0, &Bitwise.bor(BattleFlag.id(String.to_atom(&1)), &2))
  end

  defp trigger_flag(names) do
    Enum.reduce(names, 0, &Bitwise.bor(AutoTriggerFlag.id(String.to_atom(&1)), &2))
  end

  describe "generate/1 supported corpus scripts" do
    test "flat multi-key bonuses (id490160 ST_Orleans_Glove)" do
      assert {:ok, [{:bonus, :smatk, 3}, {:bonus, :spl, 2}, {:bonus, :crt, 2}]} =
               compile("bonus bSMatk,3; bonus bSpl,2; bonus bCrt,2;")
    end

    test "hp/sp capacity keys compile to their flat and rate destinations" do
      assert {:ok,
              [
                {:bonus, :max_hp, 800},
                {:bonus, :max_hp_rate, 5},
                {:bonus, :max_sp, 50},
                {:bonus, :max_sp_rate, 3}
              ]} =
               compile(
                 "bonus bMaxHP,800; bonus bMaxHPrate,5; bonus bMaxSP,50; bonus bMaxSPrate,3;"
               )
    end

    test "rate keys compile to their percentage destinations" do
      assert {:ok, [{:bonus, :aspd_rate, 10}, {:bonus, :atk_rate, 5}, {:bonus, :matk_rate, 7}]} =
               compile("bonus bAspdRate,10; bonus bAtkRate,5; bonus bMatkRate,7;")
    end

    test "bDef2Rate compiles to the soft-DEF percentage destination" do
      assert {:ok, [{:bonus, :def2_rate, 25}]} = compile("bonus bDef2Rate,25;")
    end

    test "additional item keys emit exact signed flat and parameterized destinations" do
      bash_id = skill_id!(:sm_bash)

      assert {:ok,
              [
                {:bonus, :varcast_rate, -10},
                {:bonus, :def_rate, 25},
                {:bonus, {:coma_race, :all}, 10_000},
                {:bonus, {:critical_add_race, :player_human}, -5},
                {:bonus, {:add_skill_blow, ^bash_id}, 3}
              ]} =
               compile(
                 "bonus bCastRate,-10; bonus bDefRate,25; " <>
                   "bonus2 bComaRace,RC_All,10000; " <>
                   "bonus2 bCriticalAddRace,RC_Player_Human,-5; " <>
                   "bonus2 bAddSkillBlow,SM_BASH,3;"
               )
    end

    test "additional tuple keys retain every additive contribution" do
      bash_id = skill_id!(:sm_bash)

      assert {:ok,
              [
                {:bonus, {:coma_race, :undead}, 100},
                {:bonus, {:coma_race, :undead}, 250},
                {:bonus, {:add_skill_blow, ^bash_id}, 4},
                {:bonus, {:add_skill_blow, ^bash_id}, -1}
              ]} =
               compile(
                 "bonus2 bComaRace,RC_Undead,100; " <>
                   "bonus2 bComaRace,RC_Undead,250; " <>
                   "bonus2 bAddSkillBlow,SM_BASH,4; " <>
                   "bonus2 bAddSkillBlow,SM_BASH,-1;"
               )
    end

    test "additional parameterized keys keep unresolved constants explicit" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus2 bComaRace,RC_Bogus,100;")

      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus2 bAddSkillBlow,NOT_A_SKILL,2;")
    end

    test "bAllStats compiles to the fan-out destination" do
      assert {:ok, [{:bonus, :all_stats, 2}]} = compile("bonus bAllStats,2;")
    end

    test "bSplashRange compiles to the max-merged splash destination" do
      assert {:ok, [{:bonus, :splash_range, 1}]} = compile("bonus bSplashRange,1;")
    end

    test "bHPDrainRate emits one summing instruction per argument" do
      assert {:ok, [{:bonus, :hp_drain_rate, 50}, {:bonus, :hp_drain_percent, 5}]} =
               compile("bonus2 bHPDrainRate,50,5;")
    end

    test "bHPDrainRate keeps its emission order among neighbouring bonuses" do
      assert {:ok,
              [
                {:bonus, :str, 1},
                {:bonus, :hp_drain_rate, 1000},
                {:bonus, :hp_drain_percent, 1},
                {:bonus, :agi, 2}
              ]} =
               compile("bonus bStr,1; bonus2 bHPDrainRate,1000,1; bonus bAgi,2;")
    end

    test "bHPDrainRate inside a branch expands to both instructions" do
      assert {:ok,
              [
                {:if, {:>, :refine, 7},
                 [{:bonus, :hp_drain_rate, 30}, {:bonus, :hp_drain_percent, 5}], []}
              ]} = compile("if (getrefine()>7) { bonus2 bHPDrainRate,30,5; }")
    end

    test "bHPDrainRate accepts refine-dependent amounts on both halves" do
      assert {:ok, [{:bonus, :hp_drain_rate, {:*, :refine, 10}}, {:bonus, :hp_drain_percent, 5}]} =
               compile("bonus2 bHPDrainRate,getrefine()*10,5;")
    end

    test "bHPDrainRate rejects a non-numeric first argument" do
      assert {:error, {:unsupported, {:expression, _}}} =
               compile("bonus2 bHPDrainRate,RC_Brute,5;")
    end

    test "bHPRegenRate emits an interval-keyed bonus (amount, interval)" do
      assert {:ok, [{:bonus, {:hp_regen_bonus, 10_000}, 5}]} =
               compile("bonus2 bHPRegenRate,5,10000;")
    end

    test "bHPLossRate emits an interval-keyed loss bonus" do
      assert {:ok, [{:bonus, {:hp_loss_bonus, 5_000}, 10}]} =
               compile("bonus2 bHPLossRate,10,5000;")
    end

    test "bSPRegenRate and bSPLossRate emit interval-keyed SP bonuses" do
      assert {:ok, [{:bonus, {:sp_regen_bonus, 10_000}, 3}]} =
               compile("bonus2 bSPRegenRate,3,10000;")

      assert {:ok, [{:bonus, {:sp_loss_bonus, 4_000}, 2}]} =
               compile("bonus2 bSPLossRate,2,4000;")
    end

    test "interval bonus accepts a refine-dependent amount" do
      assert {:ok, [{:bonus, {:hp_regen_bonus, 1_000}, {:*, :refine, 2}}]} =
               compile("bonus2 bHPRegenRate,getrefine()*2,1000;")
    end

    test "interval bonus rejects a non-literal interval" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus2 bHPRegenRate,5,getrefine();")
    end

    test "bMagicAddRace2 emits a race2-keyed magic bonus" do
      assert {:ok, [{:bonus, {:magic_addrace2, :goblin}, 20}]} =
               compile("bonus2 bMagicAddRace2,RC2_Goblin,20;")
    end

    test "bIgnoreDefClassRate emits a class-keyed ignore-def bonus" do
      assert {:ok, [{:bonus, {:ignore_def_class, :boss}, 50}]} =
               compile("bonus2 bIgnoreDefClassRate,Class_Boss,50;")
    end

    test "bSPGainValue compiles to the flat sp-gain destination" do
      assert {:ok, [{:bonus, :sp_gain_value, 5}]} = compile("bonus bSPGainValue,5;")
    end

    test "bMagicSPGainValue and bLongSPGainValue compile to flat sp-gain destinations" do
      assert {:ok, [{:bonus, :magic_sp_gain_value, 20}]} = compile("bonus bMagicSPGainValue,20;")
      assert {:ok, [{:bonus, :long_sp_gain_value, 15}]} = compile("bonus bLongSPGainValue,15;")
    end

    test "bAddDamageClass emits a monster-id-keyed damage bonus" do
      assert {:ok, [{:bonus, {:add_damage_class, 1917}, 10}]} =
               compile("bonus2 bAddDamageClass,1917,10;")
    end

    test "bAddDefMonster emits a monster-id-keyed physical reduction" do
      assert {:ok, [{:bonus, {:add_def_monster, 1917}, 10}]} =
               compile("bonus2 bAddDefMonster,1917,10;")
    end

    test "bAddDamageClass rejects a non-literal monster id" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus2 bAddDamageClass,RC_Brute,10;")
    end

    test "bSPGainRace emits a race-keyed sp-gain bonus" do
      assert {:ok, [{:bonus, {:sp_gain_race, :undead}, 3}]} =
               compile("bonus2 bSPGainRace,RC_Undead,3;")
    end

    test "bSPDrainValueRace emits a race-keyed flat SP drain" do
      assert {:ok, [{:bonus, {:sp_drain_race, :undead}, 4}]} =
               compile("bonus2 bSPDrainValueRace,RC_Undead,4;")
    end

    test "bExpAddClass emits a class-keyed exp bonus" do
      assert {:ok, [{:bonus, {:exp_add_class, :all}, 10}]} =
               compile("bonus2 bExpAddClass,Class_All,10;")
    end

    test "bCRate and bSPDrainValue compile to their flat destinations" do
      assert {:ok, [{:bonus, :crit_rate, 5}]} = compile("bonus bCRate,5;")
      assert {:ok, [{:bonus, :sp_drain_value, 3}]} = compile("bonus bSPDrainValue,3;")
    end

    test "bNoSizeFix and bIntravision are argument-less flag bonuses (amount 1)" do
      assert {:ok, [{:bonus, :no_size_fix, 1}]} = compile("bonus bNoSizeFix;")
      assert {:ok, [{:bonus, :intravision, 1}]} = compile("bonus bIntravision;")
    end

    test "bDefRatioAtkClass is a single-arg class flag-param bonus" do
      assert {:ok, [{:bonus, {:def_ratio_atk_class, :boss}, 1}]} =
               compile("bonus bDefRatioAtkClass,Class_Boss;")
    end

    test "bSubSkill emits a skill-keyed damage-reduction bonus" do
      assert {:ok, [{:bonus, {:sub_skill, 5}, 20}]} =
               compile("bonus2 bSubSkill,\"SM_BASH\",20;")
    end

    test "bSubDefEle emits an element-keyed defensive bonus" do
      assert {:ok, [{:bonus, {:sub_def_ele, :fire}, 10}]} =
               compile("bonus2 bSubDefEle,Ele_Fire,10;")
    end

    test "bHealPower2 and bMagicHPGainValue compile to their flat destinations" do
      assert {:ok, [{:bonus, :heal_power2, 10}]} = compile("bonus bHealPower2,10;")
      assert {:ok, [{:bonus, :magic_hp_gain_value, 30}]} = compile("bonus bMagicHPGainValue,30;")
    end

    test "bIgnoreMdefClassRate emits a class-keyed ignore-mdef bonus" do
      assert {:ok, [{:bonus, {:ignore_mdef_class, :boss}, 50}]} =
               compile("bonus2 bIgnoreMdefClassRate,Class_Boss,50;")
    end

    test "bSubRace2 emits a race2-keyed sub bonus" do
      assert {:ok, [{:bonus, {:subrace2, :goblin}, 15}]} =
               compile("bonus2 bSubRace2,RC2_Goblin,15;")
    end

    test "bAddMonsterDropItem bonus2 emits an item-keyed drop chance" do
      assert {:ok, [{:bonus, {:add_monster_drop, 519}, 100}]} =
               compile("bonus2 bAddMonsterDropItem,519,100;")
    end

    test "bAddMonsterDropItemGroup emits an item-group-keyed drop chance" do
      assert {:ok, [{:bonus, {:add_monster_drop_group, :food}, 10_000}]} =
               compile("bonus2 bAddMonsterDropItemGroup,IG_Food,10000;")
    end

    test "bAddMonsterDropItem bonus2 accepts a refine-scaled chance" do
      assert {:ok, [{:bonus, {:add_monster_drop, 7060}, {:*, 10, :refine}}]} =
               compile("bonus2 bAddMonsterDropItem,7060,10*getrefine();")
    end

    test "bAddMonsterDropItem bonus3 emits a race-gated {family, item, race} drop" do
      assert {:ok, [{:bonus, {:add_monster_drop, 517, :brute}, 3000}]} =
               compile("bonus3 bAddMonsterDropItem,517,RC_Brute,3000;")
    end

    test "bAddMonsterDropItem bonus3 rejects a non-literal item id" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus3 bAddMonsterDropItem,getrefine(),RC_Brute,3000;")
    end

    test "bAddMonsterDropItem bonus3 rejects the RC_Boss sentinel as a race" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus3 bAddMonsterDropItem,517,RC_Boss,3000;")
    end

    test "bAtkEle compiles to a :set instruction carrying the element" do
      assert {:ok, [{:set, :atk_ele, :fire}]} = compile("bonus bAtkEle,Ele_Fire;")
    end

    test "bAtkEle with an unresolvable constant is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} =
               compile("bonus bAtkEle,Ele_Bogus;")
    end

    test "bAtkEle with a numeric argument is unresolved_param, not a summed bonus" do
      assert {:error, {:unsupported, {:unresolved_param, _}}} = compile("bonus bAtkEle,3;")
    end

    test "bAtkEle rejects Ele_All - :all names no single element to :set" do
      assert {:error, {:unsupported, {:unresolved_param, "Ele_All"}}} =
               compile("bonus bAtkEle,Ele_All;")
    end

    test "refine-scaled amount (id1298 Shiver_Katar)" do
      assert {:ok, [{:bonus, :critical, :refine}]} = compile("bonus bCritical,getrefine();")
    end

    test "argument-less bonus is the boolean-flag idiom, amount 1" do
      assert {:ok, [{:bonus, :unbreakable_weapon, 1}]} = compile("bonus bUnbreakableWeapon;")
      assert {:ok, [{:bonus, :unbreakable_helm, 1}]} = compile("bonus bUnbreakableHelm;")
    end

    test "argument-less bonus with an unknown key stays unknown_bonus_key" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bNoWalkDelay"}}} =
               compile("bonus bNoWalkDelay;")
    end

    test "BaseLevel and JobLevel compile to their level inputs" do
      assert {:ok, [{:bonus, :atk, {:div, :base_level, 10}}]} =
               compile("bonus bBaseAtk,BaseLevel/10;")

      assert {:ok, [{:bonus, :matk, :job_level}]} = compile("bonus bMatk,JobLevel;")
    end

    test "BaseLevel works as an if gate" do
      assert {:ok, [{:if, {:>, :base_level, 99}, [{:bonus, :max_hp, 500}], []}]} =
               compile("if (BaseLevel>99) bonus bMaxHP,500;")
    end

    test "a ternary amount compiles to the :ternary expression" do
      assert {:ok, [{:bonus, :str, {:ternary, {:>=, :refine, 7}, 3, 1}}]} =
               compile("bonus bStr,getrefine()>=7?3:1;")
    end

    test "a nested ternary over an inlined refine var compiles" do
      assert {:ok,
              [
                {:bonus, :hit,
                 {:ternary, {:<, :refine, 7}, 1, {:ternary, {:<, :refine, 9}, 2, 3}}}
              ]} = compile(".@r = getrefine(); bonus bHit,.@r<7?1:(.@r<9?2:3);")
    end

    test "BaseClass gate resolves to a job comparison" do
      assert {:ok, [{:if, {:job_cmp, :==, :base_class, :mage}, [{:bonus, :matk, 10}], []}]} =
               compile("if (BaseClass==Job_Mage) bonus bMatk,10;")
    end

    test "assignment-inline idiom compiles the substituted expression" do
      assert {:ok, [{:bonus, :smatk, {:+, 1, {:div, :refine, 2}}}]} =
               compile(".@r = getrefine(); bonus bSMatk,1+(.@r/2);")
    end

    test "conditional refine gate (id2198 Lapine_Shield)" do
      assert {:ok, [{:bonus, :mdef, 10}, {:if, {:>, :refine, 7}, [{:bonus, :matk, 20}], []}]} =
               compile("bonus bMdef,10; if (getrefine()>7) bonus bMatk,20;")
    end

    test "if with else branch" do
      assert {:ok, [{:if, {:>=, :refine, 9}, [{:bonus, :res, 15}], [{:bonus, :res, 5}]}]} =
               compile("if (getrefine()>=9) bonus bRes,15; else bonus bRes,5;")
    end

    test "logical && and || conditions map to :and / :or" do
      assert {:ok, [{:if, {:and, {:>, :refine, 5}, {:<, :refine, 10}}, [{:bonus, :str, 1}], []}]} =
               compile("if (getrefine()>5 && getrefine()<10) bonus bStr,1;")

      assert {:ok, [{:if, {:or, {:==, :refine, 0}, {:>=, :refine, 7}}, [{:bonus, :agi, 1}], []}]} =
               compile("if (getrefine()==0 || getrefine()>=7) bonus bAgi,1;")
    end

    test "later assignment shadows the earlier binding" do
      assert {:ok, [{:bonus, :str, {:*, :refine, 2}}]} =
               compile(".@r = getrefine(); .@r = getrefine()*2; bonus bStr,.@r;")
    end

    test "nested refine gates" do
      script = "if (getrefine()>5) if (getrefine()>9) bonus bMatk,30;"

      assert {:ok,
              [{:if, {:>, :refine, 5}, [{:if, {:>, :refine, 9}, [{:bonus, :matk, 30}], []}], []}]} =
               compile(script)
    end

    test "assignment-only script yields an empty program" do
      assert {:ok, []} = compile(".@r = getrefine();")
    end
  end

  describe "generate/1 case-insensitive keys" do
    test "corpus casing and exported casing both resolve" do
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus bPAtk,20;")
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus bPatk,20;")
      assert {:ok, [{:bonus, :patk, 20}]} = compile("bonus BPATK,20;")
    end
  end

  describe "generate/1 bonus2 damage-tier commands" do
    test "each damage-tier family transpiles" do
      assert {:ok, [{:bonus, {:addrace, :brute}, 20}]} = compile("bonus2 bAddRace,RC_Brute,20;")
      assert {:ok, [{:bonus, {:subrace, :undead}, 15}]} = compile("bonus2 bSubRace,RC_Undead,15;")
      assert {:ok, [{:bonus, {:addele, :fire}, 10}]} = compile("bonus2 bAddEle,Ele_Fire,10;")
      assert {:ok, [{:bonus, {:subele, :water}, 10}]} = compile("bonus2 bSubEle,Ele_Water,10;")
      assert {:ok, [{:bonus, {:addsize, :large}, 25}]} = compile("bonus2 bAddSize,Size_Large,25;")
      assert {:ok, [{:bonus, {:subsize, :small}, 25}]} = compile("bonus2 bSubSize,Size_Small,25;")

      assert {:ok, [{:bonus, {:addclass, :boss}, 30}]} =
               compile("bonus2 bAddClass,Class_Boss,30;")

      assert {:ok, [{:bonus, {:subclass, :normal}, 5}]} =
               compile("bonus2 bSubClass,Class_Normal,5;")

      assert {:ok, [{:bonus, {:magic_addrace, :dragon}, 20}]} =
               compile("bonus2 bMagicAddRace,RC_Dragon,20;")

      assert {:ok, [{:bonus, {:magic_addele, :holy}, 20}]} =
               compile("bonus2 bMagicAddEle,Ele_Holy,20;")

      assert {:ok, [{:bonus, {:magic_addsize, :medium}, 20}]} =
               compile("bonus2 bMagicAddSize,Size_Medium,20;")

      assert {:ok, [{:bonus, {:magic_atk_ele, :shadow}, 20}]} =
               compile("bonus2 bMagicAtkEle,Ele_Dark,20;")

      assert {:ok, [{:bonus, {:ignore_def_race, :demon}, 50}]} =
               compile("bonus2 bIgnoreDefRaceRate,RC_Demon,50;")

      assert {:ok, [{:bonus, {:ignore_mdef_race, :angel}, 50}]} =
               compile("bonus2 bIgnoreMdefRaceRate,RC_Angel,50;")
    end

    test "exp_add_race transpiles for a specific race and for the RC_All wildcard" do
      assert {:ok, [{:bonus, {:exp_add_race, :all}, 10}]} =
               compile("bonus2 bExpAddRace,RC_All,10;")

      assert {:ok, [{:bonus, {:exp_add_race, :undead}, 5}]} =
               compile("bonus2 bExpAddRace,RC_Undead,5;")

      assert {:ok, [{:bonus, {:exp_add_race, :player_human}, 15}]} =
               compile("bonus2 bExpAddRace,RC_Player_Human,15;")
    end

    test "skill_atk by skill name resolves through the catalog to its integer id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_atk, ^firebolt_id}, 15}]} =
               compile("bonus2 bSkillAtk,MG_FIREBOLT,15;")
    end

    test "skill_atk by quoted skill name resolves like the bare-name form" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_atk, ^firebolt_id}, 15}]} =
               compile(~s(bonus2 bSkillAtk,"MG_FIREBOLT",15;))
    end

    test "bSkillHeal resolves the quoted skill name to a keyed heal percentage" do
      assert {:ok, [{:bonus, {:skill_heal, 28}, 3}]} =
               compile(~s(bonus2 bSkillHeal,"AL_HEAL",3;))
    end

    test "quoted skill name outside the catalog is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "XX_NOTASKILL"}}} =
               compile(~s(bonus2 bSkillAtk,"XX_NOTASKILL",15;))
    end

    test "skill_atk by raw skill id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_atk, ^firebolt_id}, 15}]} =
               compile("bonus2 bSkillAtk,#{firebolt_id},15;")
    end

    test "skill_cooldown by skill name resolves through the catalog to its integer id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_cooldown, ^firebolt_id}, -500}]} =
               compile("bonus2 bSkillCooldown,MG_FIREBOLT,-500;")
    end

    test "skill_use_sp by skill name resolves through the catalog to its integer id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_use_sp, ^firebolt_id}, -5}]} =
               compile("bonus2 bSkillUseSP,MG_FIREBOLT,-5;")
    end

    test "skill_varcast_rate by raw skill id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_varcast_rate, ^firebolt_id}, -10}]} =
               compile("bonus2 bVariableCastrate,#{firebolt_id},-10;")
    end

    test "the flat bVariableCastrate is global, the bonus2 form stays per-skill" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, :varcast_rate, -10}]} = compile("bonus bVariableCastrate,-10;")

      assert {:ok, [{:bonus, {:skill_varcast_rate, ^firebolt_id}, -10}]} =
               compile("bonus2 bVariableCastrate,#{firebolt_id},-10;")

      assert {:ok, [{:bonus, :varcast_rate, -15}]} = compile("bonus bCastrate,-15;")

      assert {:ok, [{:bonus, {:skill_varcast_rate, ^firebolt_id}, -25}]} =
               compile("bonus2 bCastrate,MG_FIREBOLT,-25;")
    end

    test "delay and long-attack rate keys" do
      assert {:ok, [{:bonus, :delay_rate, -10}]} = compile("bonus bDelayrate,-10;")
      assert {:ok, [{:bonus, :long_atk_rate, 15}]} = compile("bonus bLongAtkRate,15;")
    end

    test "regen and sp-economy keys" do
      assert {:ok, [{:bonus, :hp_regen, 10}]} = compile("bonus bHPrecovRate,10;")
      assert {:ok, [{:bonus, :sp_regen, 15}]} = compile("bonus bSPrecovRate,15;")
      assert {:ok, [{:bonus, :sp_cost_rate, -5}]} = compile("bonus bUseSPrate,-5;")
    end

    test "bSkillUseSPrate is a per-skill sp-cost percentage" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:bonus, {:skill_use_sp_rate, ^heal_id}, -25}]} =
               compile("bonus2 bSkillUseSPrate,#{heal_id},-25;")
    end

    test "fixed-cast and heal-power keys pass their amount through" do
      assert {:ok, [{:bonus, :fixed_cast, -500}]} = compile("bonus bFixedCast,-500;")
      assert {:ok, [{:bonus, :heal_power, 5}]} = compile("bonus bHealPower,5;")
    end

    test "damage-side rate keys pass their amount through unscaled" do
      assert {:ok, [{:bonus, :crit_atk_rate, 20}]} = compile("bonus bCritAtkRate,20;")
      assert {:ok, [{:bonus, :short_atk_rate, 15}]} = compile("bonus bShortAtkRate,15;")
      assert {:ok, [{:bonus, :short_atk_rate, -10}]} = compile("bonus bShortAtkRate,-10;")
      assert {:ok, [{:bonus, :perfect_hit_rate, 25}]} = compile("bonus bPerfectHitRate,25;")
      assert {:ok, [{:bonus, :perfect_hit, 50}]} = compile("bonus bPerfectHitAddRate,50;")
    end

    test "bCritAtkRate compiles to its own destination, never the crit rate one" do
      assert {:ok, [{:bonus, :crit_atk_rate, 10}]} = compile("bonus bCritAtkRate,10;")
      assert {:ok, [{:bonus, :critical, 10}]} = compile("bonus bCritical,10;")
    end

    test "bSpeedRate compiles to the non-stackable movement-speed destination" do
      assert {:ok, [{:bonus, :movement_speed, 25}]} = compile("bonus bSpeedRate,25;")
    end

    test "hit, additive speed, ranged critical, and no-regen keys compile directly" do
      assert {:ok, [{:bonus, :hit_rate, 15}]} = compile("bonus bHitRate,15;")

      assert {:ok, [{:bonus, :movement_speed_add, 20}]} =
               compile("bonus bSpeedAddRate,20;")

      assert {:ok, [{:bonus, :critical_long, 7}]} = compile("bonus bCriticalLong,7;")
      assert {:ok, [{:bonus, :no_regen, 3}]} = compile("bonus bNoRegen,3;")
    end

    test "bFlee2 is scaled x10 into per-mille perfect dodge" do
      assert {:ok, [{:bonus, :perfect_dodge, 30}]} = compile("bonus bFlee2,3;")
      assert {:ok, [{:bonus, :perfect_dodge, -20}]} = compile("bonus bFlee2,-2;")
    end

    test "bFlee2 scales the whole expression, not just literals" do
      assert {:ok, [{:bonus, :perfect_dodge, {:*, {:*, :refine, 2}, 10}}]} =
               compile(".@r = getrefine(); bonus bFlee2,.@r*2;")
    end

    test "status infliction/resist keys" do
      assert {:ok, [{:bonus, {:add_eff, :sc_stun}, 500}]} =
               compile("bonus2 bAddEff,Eff_Stun,500;")

      assert {:ok, [{:bonus, {:add_eff_when_hit, :sc_poison}, 300}]} =
               compile("bonus2 bAddEffWhenHit,Eff_Poison,300;")

      assert {:ok, [{:bonus, {:res_eff, :sc_freeze}, 1000}]} =
               compile("bonus2 bResEff,Eff_Freeze,1000;")
    end

    test "refine-expression amount" do
      assert {:ok, [{:bonus, {:addrace, :brute}, {:*, :refine, 2}}]} =
               compile("bonus2 bAddRace,RC_Brute,getrefine()*2;")
    end

    test "inside an if branch" do
      assert {:ok, [{:if, {:>, :refine, 7}, [{:bonus, {:addrace, :brute}, 20}], []}]} =
               compile("if (getrefine()>7) bonus2 bAddRace,RC_Brute,20;")
    end

    test "Ele_All transpiles to the :all wildcard the runtime read folds in" do
      assert {:ok, [{:bonus, {:subele, :all}, 20}]} = compile("bonus2 bSubEle,Ele_All,20;")
      assert {:ok, [{:bonus, {:addele, :all}, 10}]} = compile("bonus2 bAddEle,Ele_All,10;")
    end

    test "RC_Player_Doram transpiles to its (currently inert) race atom" do
      assert {:ok, [{:bonus, {:addrace, :player_doram}, 10}]} =
               compile("bonus2 bAddRace,RC_Player_Doram,10;")

      assert {:ok, [{:bonus, {:subrace, :player_doram}, 15}]} =
               compile("bonus2 bSubRace,RC_Player_Doram,15;")
    end

    test "RC_Boss redirects addrace/subrace to the class family" do
      assert {:ok, [{:bonus, {:addclass, :boss}, 30}]} = compile("bonus2 bAddRace,RC_Boss,30;")
      assert {:ok, [{:bonus, {:subclass, :boss}, 30}]} = compile("bonus2 bSubRace,RC_Boss,30;")
    end

    test "RC_Boss on a family with no class axis is rejected" do
      assert {:error, {:unsupported, {:unresolved_param, {:class, :boss}}}} =
               compile("bonus2 bMagicAddRace,RC_Boss,20;")

      assert {:error, {:unsupported, {:unresolved_param, {:class, :boss}}}} =
               compile("bonus2 bIgnoreDefRaceRate,RC_Boss,20;")
    end
  end

  describe "generate/1 defender, drain and flag keys" do
    test "flat defender and utility keys compile to their destinations" do
      assert {:ok, [{:bonus, :long_atk_def, 10}]} = compile("bonus bLongAtkDef,10;")
      assert {:ok, [{:bonus, :hp_gain_value, 50}]} = compile("bonus bHPGainValue,50;")

      assert {:ok, [{:bonus, :short_weapon_damage_return, 5}]} =
               compile("bonus bShortWeaponDamageReturn,5;")

      assert {:ok, [{:bonus, :item_heal_rate, 20}]} = compile("bonus bAddItemHealRate,20;")
    end

    test "bFixedCastrate is global as bonus and per-skill as bonus2" do
      assert {:ok, [{:bonus, :fixcast_rate, -10}]} = compile("bonus bFixedCastrate,-10;")

      assert {:ok, [{:bonus, {:skill_fixcast_rate, id}, -50}]} =
               compile(~s(bonus2 bFixedCastrate,"SM_BASH",-50;))

      assert is_integer(id)
    end

    test "bNoKnockback and bNoCastCancel are argument-less flags, amount 1" do
      assert {:ok, [{:bonus, :no_knockback, 1}]} = compile("bonus bNoKnockback;")
      assert {:ok, [{:bonus, :no_cast_cancel, 1}]} = compile("bonus bNoCastCancel;")
    end

    test "bDefEle compiles to a :set instruction carrying the element" do
      assert {:ok, [{:set, :def_ele, :holy}]} = compile("bonus bDefEle,Ele_Holy;")
    end

    test "bSPDrainRate emits one summing instruction per argument" do
      assert {:ok, [{:bonus, :sp_drain_rate, 30}, {:bonus, :sp_drain_percent, 2}]} =
               compile("bonus2 bSPDrainRate,30,2;")
    end

    test "bMagicAddClass and bDropAddRace transpile to their families" do
      assert {:ok, [{:bonus, {:magic_addclass, :boss}, 30}]} =
               compile("bonus2 bMagicAddClass,Class_Boss,30;")

      assert {:ok, [{:bonus, {:drop_add_race, :all}, 100}]} =
               compile("bonus2 bDropAddRace,RC_All,100;")
    end

    test "bAddEff2 transpiles to the self-infliction family" do
      assert {:ok, [{:bonus, {:add_eff2, :sc_curse}, 500}]} =
               compile("bonus2 bAddEff2,Eff_Curse,500;")
    end

    test "bAddItemHealRate keeps the item id verbatim as its param" do
      assert {:ok, [{:bonus, {:add_item_heal, 501}, 10}]} =
               compile("bonus2 bAddItemHealRate,501,10;")
    end

    test "class coma and item-group healing resolve their parameters" do
      assert {:ok, [{:bonus, {:coma_class, :boss}, 250}]} =
               compile("bonus2 bComaClass,Class_Boss,250;")

      assert {:ok, [{:bonus, {:add_item_group_heal, :food}, 30}]} =
               compile("bonus2 bAddItemGroupHealRate,IG_Food,30;")
    end

    test "bGetZenyNum preserves its amount and chance as one instruction" do
      assert {:ok, [{:paired_choice, :get_zeny, 100, 25}]} =
               compile("bonus2 bGetZenyNum,100,25;")
    end

    test "bAddRace2 resolves RC2 groups case-insensitively" do
      assert {:ok, [{:bonus, {:addrace2, :biolab}, 20}]} =
               compile("bonus2 bAddRace2,RC2_BioLab,20;")

      assert {:ok, [{:bonus, {:addrace2, :biolab}, 20}]} =
               compile("bonus2 bAddRace2,RC2_BIOLAB,20;")

      assert {:ok, [{:bonus, {:addrace2, :edda_arunafeltz}, 5}]} =
               compile("bonus2 bAddRace2,RC2_Edda_Arunafeltz,5;")
    end

    test "single-argument ignore-def flags carry an implicit 100 into the rate family" do
      assert {:ok, [{:bonus, {:ignore_def_race, :brute}, 100}]} =
               compile("bonus bIgnoreDefRace,RC_Brute;")

      assert {:ok, [{:bonus, {:ignore_def_race, :all}, 100}]} =
               compile("bonus bIgnoreDefRace,RC_All;")

      assert {:ok, [{:bonus, {:ignore_mdef_race, :all}, 100}]} =
               compile("bonus bIgnoreMDefRace,RC_All;")

      assert {:ok, [{:bonus, {:ignore_def_class, :normal}, 100}]} =
               compile("bonus bIgnoreDefClass,Class_Normal;")
    end

    test "an unresolvable flag param is rejected" do
      assert {:error, {:unsupported, {:unresolved_param, "RC_NotARace"}}} =
               compile("bonus bIgnoreDefRace,RC_NotARace;")
    end

    test "bAddRace2 with an unknown group is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "RC2_NotAGroup"}}} =
               compile("bonus2 bAddRace2,RC2_NotAGroup,20;")
    end
  end

  describe "generate/1 rejections (all-or-nothing)" do
    test "unknown bonus2 key" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               compile("bonus2 bMaxHP,RC_Brute,10;")
    end

    test "unsupported bonus3 keys, and out-of-vocabulary bonus4/5, stay unsupported" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus3"}}} =
               compile("bonus3 bAddMonsterDropItemGroup,IG_Jewel,RC_Brute,100;")

      assert {:error, {:unsupported, {:unsupported_command, "bonus4"}}} =
               compile("bonus4 bSubSize,Size_Large,10,BF_WEAPON,0;")

      assert {:error, {:unsupported, {:unsupported_command, "bonus5"}}} =
               compile("bonus5 bSubEle,Ele_Fire,3,BF_MAGIC,1;")
    end

    test "non-constant param is rejected" do
      assert {:error, {:unsupported, {:unresolved_param, {:var, :local, "x", :int}}}} =
               compile("bonus2 bAddRace,.@x,10;")
    end

    test "unresolvable param constant is rejected" do
      assert {:error, {:unsupported, {:unresolved_param, "RC_NotARace"}}} =
               compile("bonus2 bAddRace,RC_NotARace,10;")
    end

    test "bonus2 with a wrong-arity shape is rejected" do
      assert {:error, {:unsupported, {:bonus_shape, _}}} = compile("bonus2 bAddRace,RC_Brute;")
    end

    test "bonus3 flag-arg keys reuse the bonus2 param schema and keep the flag" do
      # on-hit status infliction (add_eff / add_eff_when_hit): trigger flags,
      # filled with the unnamed axes (both ranges, weapon type, enemy victim).
      assert {:ok, [{:bonus, {:add_eff, {:sc_stun, flag}}, 500}]} =
               compile("bonus3 bAddEff,Eff_Stun,500,ATF_TARGET;")

      assert flag == trigger_flag(~w(target short long weapon))

      assert {:ok, [{:bonus, {:add_eff, {:sc_curse, curse_flag}}, 200}]} =
               compile("bonus3 bAddEff,Eff_Curse,200,ATF_WEAPON|ATF_LONG|ATF_TARGET;")

      assert curse_flag == trigger_flag(~w(weapon long target))

      assert {:ok, [{:bonus, {:add_eff_when_hit, {:sc_blind, blind_flag}}, 300}]} =
               compile("bonus3 bAddEffWhenHit,Eff_Blind,300,ATF_SHORT;")

      assert blind_flag == trigger_flag(~w(short target weapon))

      # sub-resist family (subele / subrace / subsize / subclass): battle flags,
      # filled with both ranges and the origin the damage type implies.
      assert {:ok, [{:bonus, {:subele, {:fire, magic_flag}}, 3}]} =
               compile("bonus3 bSubEle,Ele_Fire,3,BF_MAGIC;")

      assert magic_flag == battle_flag(~w(magic short long skill))

      assert {:ok, [{:bonus, {:subrace, {:demon, weapon_flag}}, 10}]} =
               compile("bonus3 bSubRace,RC_Demon,10,BF_WEAPON;")

      assert weapon_flag == battle_flag(~w(weapon short long skill normal))

      assert {:ok, [{:bonus, {:subsize, {:large, ^weapon_flag}}, 15}]} =
               compile("bonus3 bSubSize,Size_Large,15,BF_WEAPON;")

      assert {:ok, [{:bonus, {:subclass, {:boss, normal_flag}}, 20}]} =
               compile("bonus3 bSubClass,Class_Boss,20,BF_NORMAL;")

      # An explicit origin is left alone: no skill bit is added.
      assert normal_flag == battle_flag(~w(normal weapon short long))
    end

    test "bonus3 flag-arg keys accept a refine-dependent amount" do
      assert {:ok, [{:bonus, {:subele, {:water, _flag}}, {:*, :refine, 2}}]} =
               compile("bonus3 bSubEle,Ele_Water,getrefine()*2,BF_MAGIC;")
    end

    test "an unresolvable trigger-condition flag rejects the item" do
      assert {:error, {:unsupported, {:unresolved_param, "BF_NOTAFLAG"}}} =
               compile("bonus3 bSubEle,Ele_Fire,3,BF_NOTAFLAG;")

      assert {:error, {:unsupported, {:unresolved_param, "ATF_NOTAFLAG"}}} =
               compile("bonus3 bAddEff,Eff_Stun,500,ATF_NOTAFLAG;")
    end

    test "a battle-flag key rejects a trigger-flag constant, and the reverse" do
      assert {:error, {:unsupported, {:unresolved_param, "ATF_MAGIC"}}} =
               compile("bonus3 bSubEle,Ele_Fire,3,ATF_MAGIC;")

      assert {:error, {:unsupported, {:unresolved_param, "BF_MAGIC"}}} =
               compile("bonus3 bAddEff,Eff_Stun,500,BF_MAGIC;")
    end

    test "bonus3 bAutoSpell arms an attack-trigger proc with the default flag" do
      assert {:ok, [{:auto_cast, spec, 3, 100}]} =
               compile(~S|bonus3 bAutoSpell,"MG_COLDBOLT",3,100;|)

      assert %{trigger: :attack, skill_id: skill_id, force: 0} = spec
      assert skill_id == skill_id!(:mg_coldbolt)

      # No flag argument: a weapon proc, either range, normal swings and skills.
      assert spec.flag == battle_flag(~w(weapon short long normal skill))
    end

    test "bonus3 bAutoSpellWhenHit arms the when-hit trigger" do
      assert {:ok, [{:auto_cast, %{trigger: :when_hit} = spec, 5, 20}]} =
               compile(~S|bonus3 bAutoSpellWhenHit,"AL_HEAL",5,20;|)

      assert spec.flag == battle_flag(~w(weapon short long normal skill))
    end

    test "bonus4 adds the force argument, keeping the default flag" do
      assert {:ok, [{:auto_cast, %{force: 1, trigger: :attack}, 1, 10}]} =
               compile(~S|bonus4 bAutoSpell,"MG_COLDBOLT",1,10,1;|)
    end

    test "bonus5 names both the triggering attack kinds and the force argument" do
      assert {:ok, [{:auto_cast, spec, 5, 100}]} =
               compile(~S|bonus5 bAutoSpell,"MG_FIREBOLT",5,100,BF_MAGIC,0;|)

      assert %{trigger: :attack, force: 0} = spec
      assert spec.flag == battle_flag(~w(magic short long skill))
    end

    test "an autocast level and chance may be refine- or skill-level-dependent" do
      assert {:ok, [{:auto_cast, _spec, {:max, 2, {:skill_lv, _id}}, {:+, 10, :refine}}]} =
               compile(
                 ~S|bonus3 bAutoSpell,"MG_COLDBOLT",max(2,getskilllv("MG_COLDBOLT")),10+getrefine();|
               )
    end

    test "an autocast naming a skill outside the catalog rejects the item" do
      assert {:error, {:unsupported, {:unresolved_param, "NPC_NOTASKILL"}}} =
               compile(~S|bonus3 bAutoSpell,"NPC_NOTASKILL",3,100;|)
    end

    test "an unresolvable autocast battle flag rejects the item" do
      assert {:error, {:unsupported, {:unresolved_param, "BF_NOTAFLAG"}}} =
               compile(~S|bonus5 bAutoSpell,"MG_COLDBOLT",5,100,BF_NOTAFLAG,0;|)
    end

    test "bonus4/5 keys outside their dedicated vocabularies stay unsupported" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus4"}}} =
               compile(~S|bonus4 bSubEle,Ele_Fire,3,BF_MAGIC;|)

      assert {:error, {:unsupported, {:unsupported_command, "bonus5"}}} =
               compile(~S|bonus5 bSubEle,Ele_Fire,3,BF_MAGIC,1;|)
    end

    test "vanish rates retain chance, percent and their category/race gate" do
      normal_flag = battle_flag(~w(weapon short long normal))

      assert {:ok,
              [
                {:bonus, {:sp_vanish_rate, ^normal_flag}, 80},
                {:bonus, {:sp_vanish_percent, ^normal_flag}, 30}
              ]} = compile("bonus2 bSPVanishRate,80,30;")

      weapon_flag = battle_flag(~w(weapon short long normal skill))

      assert {:ok,
              [
                {:bonus, {:sp_vanish_rate, ^weapon_flag}, 3},
                {:bonus, {:sp_vanish_percent, ^weapon_flag}, 30}
              ]} = compile("bonus3 bSPVanishRate,3,30,BF_WEAPON;")

      assert {:ok,
              [
                {:bonus, {:hp_vanish_race_rate, :player_human}, 1_000},
                {:bonus, {:hp_vanish_race_percent, :player_human}, 8}
              ]} = compile("bonus3 bHPVanishRaceRate,RC_Player_Human,1000,8;")
    end

    test "a vanish rate rejects an unknown battle flag or race" do
      assert {:error, {:unsupported, {:unresolved_param, "BF_NOTAFLAG"}}} =
               compile("bonus3 bSPVanishRate,3,30,BF_NOTAFLAG;")

      assert {:error, {:unsupported, {:unresolved_param, "RC_NotARace"}}} =
               compile("bonus3 bHPVanishRaceRate,RC_NotARace,1000,8;")
    end

    test "defender-status procs retain race, chance, duration and replacement value" do
      assert {:ok,
              [
                {:bonus, {:def_set_race_rate, :player_human}, 10_000},
                {:bonus, {:def_set_race_duration, :player_human}, 5_000},
                {:bonus, {:def_set_race_value, :player_human}, 1}
              ]} = compile("bonus4 bSetDefRace,RC_Player_Human,10000,5000,1;")

      assert {:ok,
              [
                {:bonus, {:mdef_set_race_rate, :player_doram}, 5_000},
                {:bonus, {:mdef_set_race_duration, :player_doram}, {:*, :refine, 100}},
                {:bonus, {:mdef_set_race_value, :player_doram}, 2}
              ]} = compile("bonus4 bSetMDefRace,RC_Player_Doram,5000,getrefine()*100,2;")

      assert {:ok,
              [
                {:bonus, {:no_recover_race_rate, :player_human}, 10_000},
                {:bonus, {:no_recover_race_duration, :player_human}, 10_000}
              ]} = compile("bonus3 bStateNoRecoverRace,RC_Player_Human,10000,10000;")
    end

    test "bonus3 flag-arg key with an unresolvable param is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "Eff_NotAStatus"}}} =
               compile("bonus3 bAddEff,Eff_NotAStatus,500,ATF_TARGET;")
    end

    test "bonus4 status infliction keeps its flag and duration override" do
      assert {:ok,
              [
                {:bonus, {:add_eff, {:sc_stun, flag}}, 500},
                {:bonus, {:add_eff_duration, {:sc_stun, duration_flag}}, 5_000}
              ]} = compile("bonus4 bAddEff,Eff_Stun,500,ATF_TARGET,5000;")

      assert flag == trigger_flag(~w(target short long weapon))
      assert duration_flag == flag

      assert {:ok,
              [
                {:bonus, {:add_eff_when_hit, {:sc_blind, hit_flag}}, 300},
                {:bonus, {:add_eff_when_hit_duration, {:sc_blind, hit_duration_flag}},
                 {:*, :refine, 100}}
              ]} =
               compile("bonus4 bAddEffWhenHit,Eff_Blind,300,ATF_SHORT,getrefine()*100;")

      assert hit_duration_flag == hit_flag
    end

    test "unknown Eff_ status param is rejected" do
      assert {:error, {:unsupported, {:unresolved_param, "Eff_NotAStatus"}}} =
               compile("bonus2 bAddEff,Eff_NotAStatus,500;")
    end

    test "mixed supported and unsupported bonus2 rejects the whole item" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               compile("bonus2 bAddRace,RC_Brute,20; bonus2 bMaxHP,RC_Brute,10;")
    end

    test "unknown bonus key" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bClassChange"}}} =
               compile("bonus bClassChange,2;")
    end

    test "a conditional read outside the inputs is rejected" do
      assert {:error, {:unsupported, {:unsupported_call, "getequiprefinerycnt"}}} =
               compile("if (getequiprefinerycnt(EQI_HAND_R)>5) bonus bStr,10;")
    end

    test "unassigned variable is rejected" do
      assert {:error, {:unsupported, {:unassigned_var, "z"}}} = compile("bonus bStr,.@z;")
    end

    test "rand in an amount is rejected" do
      assert {:error, {:unsupported, {:unsupported_call, "rand"}}} =
               compile("bonus bStr,rand(1,5);")
    end

    test "the first violation aborts the whole item" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bClassChange"}}} =
               compile("bonus bStr,5; bonus bClassChange,2; bonus bAgi,3;")
    end

    test "bonus with more than two args is rejected" do
      assert {:error, {:unsupported, {:bonus_shape, _}}} = compile("bonus bStr,1,2;")
    end
  end

  describe "job comparisons" do
    test "BaseClass equality resolves to a job_cmp condition" do
      assert {:ok, [{:if, {:job_cmp, :==, :base_class, :swordman}, [{:bonus, :str, 1}], []}]} =
               compile("if (BaseClass == Job_Swordman) bonus bStr,1;")
    end

    test "Class equality against an advanced job resolves via the derived class map" do
      assert {:ok, [{:if, {:job_cmp, :==, :class, :lord_knight}, [{:bonus, :atk, 10}], []}]} =
               compile("if (Class == Job_Lord_Knight) bonus bBaseAtk,10;")
    end

    test "inequality resolves to a negated job_cmp" do
      assert {:ok, [{:if, {:job_cmp, :!=, :class, :soul_linker}, [{:bonus, :int, 1}], []}]} =
               compile("if (Class!=Job_Soul_Linker) bonus bInt,1;")
    end

    test "BaseJob reader resolves the trans/baby-collapsed reader" do
      assert {:ok, [{:if, {:job_cmp, :==, :base_job, :novice}, [{:bonus, :max_hp, 30}], []}]} =
               compile("if (BaseJob == Job_Novice) bonus bMaxHP,30;")
    end

    test "a lowercase class reader is accepted" do
      assert {:ok, [{:if, {:job_cmp, :==, :class, :ninja}, [{:bonus, :agi, 1}], []}]} =
               compile("if (class == Job_Ninja) bonus bAgi,1;")
    end

    test "job comparisons combine under || into a logic condition" do
      assert {:ok,
              [
                {:if,
                 {:or, {:job_cmp, :==, :base_class, :mage},
                  {:job_cmp, :==, :base_class, :archer}},
                 [{:bonus, :max_hp, {:*, :base_level, 5}}], []}
              ]} =
               compile(
                 "if (BaseClass == Job_Mage || BaseClass == Job_Archer) bonus bMaxHP,(BaseLevel*5);"
               )
    end

    test "an unknown job constant is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "Job_NotAJob"}}} =
               compile("if (Class == Job_NotAJob) bonus bStr,1;")
    end
  end

  describe "comparison used as an integer" do
    test "a bare comparison compiles to a bool expression" do
      assert {:ok,
              [
                {:bonus, :def,
                 {:+, {:+, 2, {:*, 3, {:bool, {:>, :refine, 5}}}},
                  {:*, 2, {:bool, {:>, :refine, 8}}}}}
              ]} = compile("bonus bDef,2+3*(getrefine()>5)+2*(getrefine()>8);")
    end
  end

  describe "conditional assignment (branch-merged ternary)" do
    test "a var assigned in one branch folds into a ternary at its later use" do
      assert {:ok, [{:bonus, :str, {:ternary, {:>, :refine, 7}, 5, 0}}]} =
               compile("if (getrefine()>7) .@x = 5;\nbonus bStr,.@x;")
    end

    test "if/else-if assignments nest into nested ternaries" do
      src = """
      .@r = getrefine();
      if (.@r >= 9) { .@val = 40; } else if (.@r >= 7) { .@val = 20; }
      bonus bStr,.@val;
      """

      assert {:ok,
              [
                {:bonus, :str,
                 {:ternary, {:>=, :refine, 9}, 40, {:ternary, {:>=, :refine, 7}, 20, 0}}}
              ]} = compile(src)
    end

    test "a compound assignment inside a branch reads the pre-if value" do
      src = """
      .@b = 40;
      if (getrefine()>=5) { .@b += 10; }
      bonus bStr,.@b;
      """

      assert {:ok, [{:bonus, :str, {:ternary, {:>=, :refine, 5}, {:+, 40, 10}, 40}}]} =
               compile(src)
    end

    test "a bonus inside a branch inlines the branch-local value directly" do
      src = """
      if (getrefine()>=7) { .@val = 10; bonus bStr,.@val; }
      """

      assert {:ok, [{:if, {:>=, :refine, 7}, [{:bonus, :str, 10}], []}]} = compile(src)
    end

    test "a var reassigned to the same value in both branches skips the ternary" do
      src = """
      if (getrefine()>=7) { .@v = 3; } else { .@v = 3; }
      bonus bStr,.@v;
      """

      assert {:ok, [{:bonus, :str, 3}]} = compile(src)
    end
  end

  describe "skill grant command" do
    test "skill by name resolves to a grant_skill instruction at the given level" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:grant_skill, ^heal_id, 5}]} = compile("skill AL_HEAL,5;")
    end

    test "skill command is case-insensitive (id1599 Angra Manyu)" do
      assert {:ok, %{id: meteor_id}} = Catalog.by_name(:wz_meteor)

      assert {:ok, [{:grant_skill, ^meteor_id, 10}]} = compile(~s(Skill "WZ_METEOR",10;))
    end

    test "skill by quoted name resolves like the bare-name form" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:grant_skill, ^heal_id, 5}]} = compile(~s(skill "AL_HEAL",5;))
    end

    test "skill by raw id resolves through the catalog" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:grant_skill, ^heal_id, 3}]} = compile("skill #{heal_id},3;")
    end

    test "the optional trigger flag is dropped" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:grant_skill, ^heal_id, 1}]} = compile("skill AL_HEAL,1,0;")
    end

    test "an unknown skill name is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "XX_NOTASKILL"}}} =
               compile("skill XX_NOTASKILL,1;")
    end
  end

  describe "getskilllv read" do
    test "getskilllv by name resolves to a skill_lv expression" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:bonus, :heal_power, {:skill_lv, ^heal_id}}]} =
               compile("bonus bHealPower,getskilllv(AL_HEAL);")
    end

    test "getskilllv by quoted name resolves like the bare-name form" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:bonus, :heal_power, {:skill_lv, ^heal_id}}]} =
               compile("bonus bHealPower,getskilllv(\"AL_HEAL\");")
    end

    test "getskilllv call is case-insensitive (id1736 Double Bound)" do
      assert {:ok, %{id: double_id}} = Catalog.by_name(:ac_double)

      assert {:ok, [{:auto_cast, _spec, {:skill_lv, ^double_id}, 10}]} =
               compile(~S|bonus3 bAutoSpell,"AC_DOUBLE",GetSkillLv("AC_DOUBLE"),10;|)
    end

    test "getskilllv is usable inside an input-pure condition" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:if, {:>, {:skill_lv, ^heal_id}, 0}, [{:bonus, :int, 3}], []}]} =
               compile("if (getskilllv(AL_HEAL)>0) bonus bInt,3;")
    end

    test "an unknown getskilllv skill is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "XX_NOTASKILL"}}} =
               compile("bonus bInt,getskilllv(XX_NOTASKILL);")
    end
  end

  describe "readparam read" do
    test "a base stat readparam resolves to a stat expression" do
      assert {:ok, [{:bonus, :atk, {:div, {:stat, :str}, 10}}]} =
               compile("bonus bBaseAtk,readparam(bStr)/10;")
    end

    test "a trait stat readparam resolves to its stat atom" do
      assert {:ok, [{:bonus, :patk, {:div, {:stat, :pow}, 15}}]} =
               compile("bonus bPAtk,readparam(bPow)/15;")
    end

    test "readparam is usable inside an input-pure condition" do
      assert {:ok, [{:if, {:>=, {:stat, :str}, 120}, [{:bonus, :atk, 10}], []}]} =
               compile("if (readparam(bStr)>=120) bonus bBaseAtk,10;")
    end

    test "multiple readparams combine in one arithmetic expression" do
      assert {:ok, [{:bonus, :hit, {:div, {:+, {:stat, :str}, {:stat, :dex}}, 12}}]} =
               compile("bonus bHit,(readparam(bStr)+readparam(bDex))/12;")
    end

    test "a non-stat readparam parameter is unresolved_param" do
      assert {:error, {:unsupported, {:unresolved_param, "bMaxHP"}}} =
               compile("bonus bInt,readparam(bMaxHP);")
    end
  end

  describe "min/max/pow math combinators" do
    test "min over a level input clamps then scales" do
      assert {:ok, [{:bonus, :atk, {:div, {:min, :base_level, 195}, 15}}]} =
               compile("bonus bBaseAtk,min(BaseLevel,195)/15;")
    end

    test "max over refine" do
      assert {:ok, [{:bonus, :atk, {:max, 1, :refine}}]} =
               compile("bonus bBaseAtk,max(1,getrefine());")
    end

    test "pow of a clamped refine nests min inside pow" do
      assert {:ok, [{:bonus, :atk, {:pow, {:min, :refine, 15}, 2}}]} =
               compile("bonus bBaseAtk,pow(min(getrefine(),15),2);")
    end

    test "pow with an arithmetic base and a scaling divisor" do
      assert {:ok, [{:bonus, :atk, {:div, {:*, {:pow, :refine, 2}, 125}, 100}}]} =
               compile("bonus bBaseAtk,pow(getrefine(),2)*125/100;")
    end

    test "max over a learned skill level resolves the skill inside" do
      assert {:ok, %{id: heal_id}} = Catalog.by_name(:al_heal)

      assert {:ok, [{:bonus, :heal_power, {:max, 1, {:skill_lv, ^heal_id}}}]} =
               compile("bonus bHealPower,max(1,getskilllv(AL_HEAL));")
    end

    test "an unresolvable operand inside a combinator propagates the error" do
      assert {:error, {:unsupported, {:unsupported_call, "rand"}}} =
               compile("bonus bInt,min(rand(5),3);")
    end
  end

  describe "autobonus and status commands" do
    test "autobonus compiles its primary program with the default attack flag" do
      assert {:ok, [{:autobonus, spec, 50, 5_000}]} =
               compile(~S|autobonus "{ bonus bStr,5; }",50,5000;|)

      assert %{
               trigger: :attack,
               battle_flag: flag,
               primary: [{:bonus, :str, 5}],
               secondary: []
             } = spec

      assert flag == battle_flag(~w(weapon short long normal skill))
    end

    test "autobonus2 compiles flags and secondary status effects while omitting cosmetics" do
      script =
        ~S'autobonus2 "{ bonus bVit,10; }",25,3000,BF_MAGIC|BF_LONG,"{ specialeffect2 EF_HEAL; sc_start SC_BLESSING,2000,3; showscript \"ready\"; }";'

      assert {:ok, [{:autobonus, spec, 25, 3_000}]} = compile(script)

      assert %{
               trigger: :when_hit,
               battle_flag: flag,
               primary: [{:bonus, :vit, 10}],
               secondary: [{:status_start, :sc_blessing, 2_000, 3}]
             } = spec

      assert flag == battle_flag(~w(magic long skill))
    end

    test "autobonus3 resolves its trigger skill and status effects" do
      bash_id = skill_id!(:sm_bash)

      script =
        ~S'autobonus3 "{ sc_start SC_BLESSING,5000,2; }",1000,6000,"SM_BASH","{ sc_end SC_CURSE; }";'

      assert {:ok, [{:autobonus, spec, 1_000, 6_000}]} = compile(script)

      assert %{
               trigger: {:on_skill, ^bash_id},
               battle_flag: 0,
               primary: [{:status_start, :sc_blessing, 5_000, 2}],
               secondary: [{:status_end, :sc_curse}]
             } = spec
    end

    test "dynamic nested source strings capture outer input-pure expressions" do
      script =
        ~S'.@r = getrefine(); autobonus "{ bonus bBaseAtk,25*"+.@r+"; }",3*.@r,3000,BF_NORMAL;'

      assert {:ok, [{:autobonus, spec, {:*, 3, :refine}, 3_000}]} = compile(script)
      assert spec.primary == [{:bonus, :atk, {:*, 25, :refine}}]
      assert spec.battle_flag == battle_flag(~w(normal weapon short long))
    end

    test "dynamic nested source capture is isolated from literal local assignments" do
      script =
        ~S'.@r=getrefine(); autobonus "{ .@__aesir_nested_0=7; bonus bStr,"+.@r+"; }",10,1000;'

      assert {:ok, [{:autobonus, spec, 10, 1_000}]} = compile(script)
      assert spec.primary == [{:bonus, :str, :refine}]
    end

    test "dynamic nested source keeps multiple captured expressions distinct" do
      script =
        ~S'.@r=getrefine(); autobonus "{ .@__aesir_nested_0=7; bonus bStr,"+.@r+"; bonus bAgi,"+(.@r+1)+"; }",10,1000;'

      assert {:ok, [{:autobonus, spec, 10, 1_000}]} = compile(script)

      assert spec.primary == [
               {:bonus, :str, :refine},
               {:bonus, :agi, {:+, :refine, 1}}
             ]
    end

    test "direct equip and unequip status commands use their lifecycle contexts" do
      assert {:ok, [{:status_start, :sc_summer, :infinite, 0}]} =
               compile("sc_start SC_SUMMER,INFINITE_TICK,0;")

      assert {:ok, [{:status_end, :sc_summer}]} = compile("sc_end SC_SUMMER;", :unequip)

      assert {:error, {:unsupported, {:unsupported_command, "sc_end"}}} =
               compile("sc_end SC_SUMMER;")

      assert {:error, {:unsupported, {:unsupported_command, "sc_start"}}} =
               compile("sc_start SC_SUMMER,1000,0;", :unequip)

      assert {:error, {:unsupported, {:unsupported_command, "bonus"}}} =
               compile("bonus bStr,1;", :unequip)
    end

    test "secondary programs reject gameplay commands with their nested reason" do
      script = ~S'autobonus "{}",10,1000,0,"{ bonus bStr,1; }";'

      assert {:error, {:unsupported, {:unsupported_command, "bonus"}}} = compile(script)
    end

    test "all three nested cosmetics are omitted and top-level cosmetics stay unsupported" do
      script =
        ~S'autobonus "{ specialeffect2 EF_HEAL; active_transform 1002,1000; showscript \"ok\"; bonus bStr,1; }",10,1000;'

      assert {:ok, [{:autobonus, %{primary: [{:bonus, :str, 1}]}, 10, 1_000}]} =
               compile(script)

      assert {:error, {:unsupported, {:unsupported_command, "specialeffect2"}}} =
               compile("specialeffect2 EF_HEAL;")
    end

    test "remaining source arities compile with defaults and optional data" do
      bash_id = skill_id!(:sm_bash)

      assert {:ok, [{:autobonus, attack, 10, 1_000}]} =
               compile(~S'autobonus "{}",10,1000,BF_MAGIC;')

      assert attack.trigger == :attack
      assert attack.battle_flag == battle_flag(~w(magic short long skill))
      assert attack.secondary == []

      assert {:ok, [{:autobonus, when_hit, 20, 2_000}]} =
               compile(~S'autobonus2 "{}",20,2000;')

      assert when_hit.trigger == :when_hit
      assert when_hit.battle_flag == battle_flag(~w(weapon short long normal skill))

      assert {:ok, [{:autobonus, zero_flag, 30, 3_000}]} =
               compile(~S'autobonus "{}",30,3000,0,"{}";')

      assert zero_flag.battle_flag == battle_flag(~w(weapon short long normal skill))
      assert zero_flag.secondary == []

      assert {:ok, [{:autobonus, on_skill, 1_000, 4_000}]} =
               compile("autobonus3 \"{}\",1000,4000,#{bash_id};")

      assert on_skill.trigger == {:on_skill, bash_id}
      assert on_skill.secondary == []
    end

    test "nested parser errors name the outer command and retain the parser reason" do
      nested = "{ bonus bStr,; }"
      assert {:error, nested_reason} = Parser.parse_body(nested)

      assert {:error, {:unsupported, {:nested_parse_error, "autobonus2", ^nested_reason}}} =
               compile("autobonus2 #{inspect(nested)},10,1000;")
    end

    test "nested heal compiles as a signed proc effect (id2005 Dea Staff)" do
      heal_id = skill_id!(:al_heal)

      script =
        ~S'autobonus3 "{ }",20,1000,"AL_HEAL","{ specialeffect2 EF_MAGICALATTHIT; heal 0,200; }";'

      assert {:ok, [{:autobonus, spec, 20, 1_000}]} = compile(script)
      assert spec.trigger == {:on_skill, heal_id}
      assert spec.primary == []
      assert spec.secondary == [{:heal, 0, 200}]
    end

    test "direct equip healing remains unsupported" do
      assert {:error, {:unsupported, {:unsupported_command, "heal"}}} =
               compile("heal 100,0;")
    end

    test "invalid nested bonuses and recursive autobonuses fail explicitly" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bNotReal"}}} =
               compile(~S'autobonus "{ bonus bNotReal,1; }",10,1000;')

      assert {:error, {:unsupported, {:recursive_autobonus, "autobonus3"}}} =
               compile(~S'autobonus "{ autobonus3 \"{}\",1000,1000,\"SM_BASH\"; }",10,1000;')
    end

    test "unknown status, skill, and flag symbols preserve resolver failures" do
      assert {:error, {:unsupported, {:unresolved_param, "SC_NOT_REAL"}}} =
               compile("sc_start SC_NOT_REAL,1000,1;")

      assert {:error, {:unsupported, {:unresolved_param, "XX_NOTASKILL"}}} =
               compile(~S'autobonus3 "{}",1000,1000,"XX_NOTASKILL";')

      assert {:error, {:unsupported, {:unresolved_param, "BF_NOTAFLAG"}}} =
               compile(~S'autobonus "{}",10,1000,BF_NOTAFLAG;')
    end

    test "INFINITE_TICK is accepted only as a status duration" do
      assert {:ok,
              [{:autobonus, %{primary: [{:status_start, :sc_blessing, :infinite, 1}]}, 10, 1_000}]} =
               compile(~S'autobonus "{ sc_start SC_BLESSING,INFINITE_TICK,1; }",10,1000;')

      assert {:error, {:unsupported, {:expression, {:name, "INFINITE_TICK"}}}} =
               compile(~S'autobonus "{}",10,INFINITE_TICK;')

      assert {:error, {:unsupported, {:expression, {:name, "INFINITE_TICK"}}}} =
               compile("sc_start SC_BLESSING,1000,INFINITE_TICK;")
    end
  end
end
