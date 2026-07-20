defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.PriestAcolyteDependenciesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlAngelus
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlBlessing
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCrucis
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlCure
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDecagi
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDemonbane
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDp
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHeal
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolylight
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlHolywater
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneuma
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlRuwach
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlTeleport
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlWarp

  # rAthena's Acolyte tree is db/re/skill_tree.yml:169-231. Each source
  # reference below identifies the behavior this regression locks down.
  @audited_skills [
    %{
      name: :al_angelus,
      id: 33,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :self,
        status: :sc_angelus,
        splash_radius: 18,
        sp_cost: [23, 26, 29, 32, 35, 38, 41, 44, 47, 50],
        cooldown: List.duplicate(30_000, 10)
      },
      module: AlAngelus,
      evidence: "db/re/skill_db.yml:1549-1607; skills/acolyte/angelus.cpp:14-31 party splash"
    },
    %{
      name: :al_blessing,
      id: 34,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :target_ally,
        status: :sc_blessing,
        range: 9,
        sp_cost: [28, 32, 36, 40, 44, 48, 52, 56, 60, 64],
        duration: [
          60_000,
          80_000,
          100_000,
          120_000,
          140_000,
          160_000,
          180_000,
          200_000,
          220_000,
          240_000
        ]
      },
      module: AlBlessing,
      evidence: "db/re/skill_db.yml:1609-1662; skills/acolyte/blessing.cpp:14-33 status path"
    },
    %{
      name: :al_crucis,
      id: 32,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :self,
        splash_radius: 15,
        sp_cost: List.duplicate(35, 10)
      },
      module: AlCrucis,
      evidence: "db/re/skill_db.yml:1531-1547; skills/acolyte/crucis.cpp:14-28 area chance"
    },
    %{
      name: :al_cure,
      id: 35,
      capability: :active,
      definition_contract: %{
        max_level: 1,
        target_type: :target_ally,
        range: 9,
        sp_cost: [15],
        after_cast_delay: [1_000]
      },
      module: AlCure,
      evidence: "db/re/skill_db.yml:1664-1677; skills/acolyte/cure.cpp:13-27 four cures"
    },
    %{
      name: :al_decagi,
      id: 30,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :target_enemy,
        range: 9,
        sp_cost: [15, 17, 19, 21, 23, 25, 27, 29, 31, 33],
        duration: [
          40_000,
          50_000,
          60_000,
          70_000,
          80_000,
          90_000,
          100_000,
          110_000,
          120_000,
          130_000
        ]
      },
      module: AlDecagi,
      evidence: "db/re/skill_db.yml:1455-1513; skills/acolyte/decagi.cpp:13-21 rate"
    },
    %{
      name: :al_demonbane,
      id: 23,
      capability: :passive,
      definition_contract: %{max_level: 10, target_type: :passive},
      module: AlDemonbane,
      evidence: "db/re/skill_db.yml:1242-1245; battle.cpp:2291-2294 PvE ATK"
    },
    %{
      name: :al_dp,
      id: 22,
      capability: :passive,
      definition_contract: %{max_level: 10, target_type: :passive},
      module: AlDp,
      evidence: "db/re/skill_db.yml:1237-1240; battle.cpp:4816-4818 soft DEF"
    },
    %{
      name: :al_heal,
      id: 28,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :target_any,
        range: 9,
        element: :holy,
        sp_cost: [13, 16, 19, 22, 25, 28, 31, 34, 37, 40]
      },
      module: AlHeal,
      evidence: "db/re/skill_db.yml:1354-1394; skills/acolyte/heal.cpp:13-67 living and undead"
    },
    %{
      name: :al_holylight,
      id: 156,
      capability: :active,
      definition_contract: %{
        max_level: 1,
        target_type: :target_enemy,
        damage_kind: :magic,
        element: :holy,
        range: 9,
        cast_time: [800],
        fixed_cast_time: [200],
        sp_cost: [15]
      },
      module: AlHolylight,
      evidence: "db/re/skill_db.yml:5377-5396; holylight.cpp:13-26; battle.cpp:1301"
    },
    %{
      name: :al_holywater,
      id: 31,
      capability: :active,
      definition_contract: %{
        max_level: 1,
        target_type: :self,
        cast_time: [800],
        fixed_cast_time: [200],
        after_cast_delay: [500],
        sp_cost: [10],
        item_cost: [%{id: 713, amount: 1}]
      },
      module: AlHolywater,
      evidence: "db/re/skill_db.yml:1515-1529; skills/acolyte/holywater.cpp:12-29 water craft"
    },
    %{
      name: :al_incagi,
      id: 29,
      capability: :active,
      definition_contract: %{
        max_level: 10,
        target_type: :target_ally,
        status: :sc_increaseagi,
        range: 9,
        sp_cost: [18, 21, 24, 27, 30, 33, 36, 39, 42, 45],
        duration: [
          60_000,
          80_000,
          100_000,
          120_000,
          140_000,
          160_000,
          180_000,
          200_000,
          220_000,
          240_000
        ]
      },
      module: AlIncagi,
      evidence: "db/re/skill_db.yml:1396-1453; skills/acolyte/incagi.cpp:12-31 status path"
    },
    %{
      name: :al_pneuma,
      id: 25,
      capability: :ground,
      definition_contract: %{
        max_level: 1,
        target_type: :ground,
        range: 9,
        splash_radius: 1,
        hit_interval: 1_000,
        unit_duration: [10_000],
        sp_cost: [10]
      },
      module: AlPneuma,
      evidence: "db/re/skill_db.yml:1268-1289; skills/acolyte/pneuma.cpp:9-14 field"
    },
    %{
      name: :al_ruwach,
      id: 24,
      capability: :active,
      definition_contract: %{max_level: 1, target_type: :self, sp_cost: [10]},
      module: AlRuwach,
      evidence: "db/re/skill_db.yml:1247-1266; skills/acolyte/ruwach.cpp:13-24 reveal splash"
    },
    %{
      name: :al_teleport,
      id: 26,
      capability: :active,
      definition_contract: %{max_level: 2, target_type: :self, sp_cost: [10, 9]},
      module: AlTeleport,
      evidence: "db/re/skill_db.yml:1291-1308; skills/acolyte/teleport.cpp:15-48 destinations"
    },
    %{
      name: :al_warp,
      id: 27,
      capability: :ground,
      definition_contract: %{
        max_level: 4,
        target_type: :ground,
        range: 9,
        fixed_cast_time: [1_000, 1_000, 1_000, 1_000],
        after_cast_delay: [1_000, 1_000, 1_000, 1_000],
        unit_duration: [10_000, 15_000, 20_000, 25_000],
        sp_cost: [35, 32, 29, 26],
        item_cost: [%{id: 717, amount: 1}]
      },
      module: AlWarp,
      evidence: "db/re/skill_db.yml:1310-1352; skills/acolyte/warpportal.cpp:13-37 portal menu"
    }
  ]

  test "the full Priest dependency audit names every inherited Acolyte skill and its Renewal evidence" do
    assert Enum.map(@audited_skills, & &1.name) == [
             :al_angelus,
             :al_blessing,
             :al_crucis,
             :al_cure,
             :al_decagi,
             :al_demonbane,
             :al_dp,
             :al_heal,
             :al_holylight,
             :al_holywater,
             :al_incagi,
             :al_pneuma,
             :al_ruwach,
             :al_teleport,
             :al_warp
           ]

    assert Enum.all?(@audited_skills, &String.contains?(&1.evidence, "db/re/"))
    assert Enum.all?(@audited_skills, &String.contains?(&1.evidence, ".cpp:"))
  end

  test "every audited dependency locks its exact Renewal definition contract and capability" do
    Enum.each(@audited_skills, fn %{
                                    name: name,
                                    id: id,
                                    capability: capability,
                                    definition_contract: definition_contract,
                                    module: module
                                  } ->
      assert {:ok, definition} = Catalog.by_name(name)
      assert definition.id == id
      assert Map.take(definition, Map.keys(definition_contract)) == definition_contract
      assert {:ok, ^module} = module_for(capability, name)
    end)
  end

  defp module_for(:active, name), do: Catalog.active_module_for(name)
  defp module_for(:ground, name), do: Catalog.ground_module_for(name)
  defp module_for(:passive, name), do: Catalog.passive_module_for(name)
end
