defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegenTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.EquipCodegen
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Npc.Transpiler.Parser

  defp compile(script) do
    with {:ok, stmts} <- Parser.parse_body(script) do
      EquipCodegen.generate(stmts)
    end
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

    test "bAllStats compiles to the fan-out destination" do
      assert {:ok, [{:bonus, :all_stats, 2}]} = compile("bonus bAllStats,2;")
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

    test "refine-scaled amount (id1298 Shiver_Katar)" do
      assert {:ok, [{:bonus, :critical, :refine}]} = compile("bonus bCritical,getrefine();")
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

    test "skill_atk by skill name resolves through the catalog to its integer id" do
      assert {:ok, %{id: firebolt_id}} = Catalog.by_name(:mg_firebolt)

      assert {:ok, [{:bonus, {:skill_atk, ^firebolt_id}, 15}]} =
               compile("bonus2 bSkillAtk,MG_FIREBOLT,15;")
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

    test "bSpeedRate compiles to the non-stackable movement-speed destination" do
      assert {:ok, [{:bonus, :movement_speed, 25}]} = compile("bonus bSpeedRate,25;")
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

  describe "generate/1 rejections (all-or-nothing)" do
    test "unknown bonus2 key" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bMaxHP"}}} =
               compile("bonus2 bMaxHP,RC_Brute,10;")
    end

    test "bonus3/4/5 are unsupported commands" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus3"}}} =
               compile("bonus3 bAddMonsterDropItem,501,100;")

      assert {:error, {:unsupported, {:unsupported_command, "bonus4"}}} =
               compile("bonus4 bAutoSpell,MG_FIREBOLT,5,20,0;")

      assert {:error, {:unsupported, {:unsupported_command, "bonus5"}}} =
               compile("bonus5 bAutoSpell,MG_FIREBOLT,5,20,0,BF_WEAPON;")
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

    test "bonus3/4 bAddEff forms with atf flag/duration are rejected" do
      assert {:error, {:unsupported, {:unsupported_command, "bonus3"}}} =
               compile("bonus3 bAddEff,Eff_Stun,500,ATF_TARGET;")

      assert {:error, {:unsupported, {:unsupported_command, "bonus4"}}} =
               compile("bonus4 bAddEff,Eff_Stun,500,ATF_TARGET,5000;")
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
      assert {:error, {:unsupported, {:unknown_bonus_key, "bSplashRange"}}} =
               compile("bonus bSplashRange,2;")
    end

    test "non-refine conditional read is rejected" do
      assert {:error, {:unsupported, {:expression, {:name, "BaseLevel"}}}} =
               compile("if (BaseLevel>90) bonus bStr,10;")
    end

    test "conditional assignment is rejected" do
      assert {:error, {:unsupported, {:conditional_assignment, "x"}}} =
               compile("if (getrefine()>7) .@x = 5;")
    end

    test "unassigned variable is rejected" do
      assert {:error, {:unsupported, {:unassigned_var, "z"}}} = compile("bonus bStr,.@z;")
    end

    test "rand in an amount is rejected" do
      assert {:error, {:unsupported, {:unsupported_call, "rand"}}} =
               compile("bonus bStr,rand(1,5);")
    end

    test "the first violation aborts the whole item" do
      assert {:error, {:unsupported, {:unknown_bonus_key, "bSplashRange"}}} =
               compile("bonus bStr,5; bonus bSplashRange,2; bonus bAgi,3;")
    end

    test "bonus with a non-two-arg shape is rejected" do
      assert {:error, {:unsupported, {:bonus_shape, _}}} = compile("bonus bStr;")
    end
  end
end
