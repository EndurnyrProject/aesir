defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MonkCatalogTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.Skill.Catalog

  @monk_skills [
    %{
      name: :mo_ironhand,
      id: 259,
      display_name: "Iron Fists",
      max_level: 10,
      target_type: :passive,
      capability: :passive
    },
    %{
      name: :mo_spiritsrecovery,
      id: 260,
      display_name: "Spiritual Cadence",
      max_level: 5,
      target_type: :passive,
      capability: :passive
    },
    %{
      name: :mo_callspirits,
      id: 261,
      display_name: "Summon Spirit Sphere",
      max_level: 5,
      target_type: :self,
      capability: :active
    },
    %{
      name: :mo_absorbspirits,
      id: 262,
      display_name: "Absorb Spirit Sphere",
      max_level: 1,
      target_type: :target_any,
      capability: :active
    },
    %{
      name: :mo_tripleattack,
      id: 263,
      display_name: "Raging Trifecta Blow",
      max_level: 10,
      target_type: :passive,
      capability: :passive
    },
    %{
      name: :mo_bodyrelocation,
      id: 264,
      display_name: "Snap",
      max_level: 1,
      target_type: :ground,
      capability: :active
    },
    %{
      name: :mo_dodge,
      id: 265,
      display_name: "Dodge",
      max_level: 10,
      target_type: :passive,
      capability: :passive
    },
    %{
      name: :mo_investigate,
      id: 266,
      display_name: "Occult Impaction",
      max_level: 5,
      target_type: :target_enemy,
      capability: :active
    },
    %{
      name: :mo_fingeroffensive,
      id: 267,
      display_name: "Throw Spirit Sphere",
      max_level: 5,
      target_type: :target_enemy,
      capability: :active
    },
    %{
      name: :mo_steelbody,
      id: 268,
      display_name: "Mental Strength",
      max_level: 5,
      target_type: :self,
      capability: :active
    },
    %{
      name: :mo_bladestop,
      id: 269,
      display_name: "Root",
      max_level: 5,
      target_type: :self,
      capability: :active
    },
    %{
      name: :mo_explosionspirits,
      id: 270,
      display_name: "Fury",
      max_level: 5,
      target_type: :self,
      capability: :active
    },
    %{
      name: :mo_extremityfist,
      id: 271,
      display_name: "Asura Strike",
      max_level: 5,
      target_type: :target_enemy,
      capability: :active
    },
    %{
      name: :mo_chaincombo,
      id: 272,
      display_name: "Raging Quadruple Blow",
      max_level: 5,
      target_type: :target_enemy,
      capability: :active
    },
    %{
      name: :mo_combofinish,
      id: 273,
      display_name: "Raging Thrust",
      max_level: 5,
      target_type: :target_enemy,
      capability: :active
    },
    %{
      name: :mo_kitranslation,
      id: 1_015,
      display_name: "Ki Translation",
      max_level: 1,
      target_type: :target_ally,
      capability: :active
    },
    %{
      name: :mo_balkyoung,
      id: 1_016,
      display_name: "Ki Explosion",
      max_level: 1,
      target_type: :target_enemy,
      capability: :active
    }
  ]

  setup do
    :ok = Catalog.reload()
  end

  test "reload/0 discovers all 17 Monk definitions with no gaps and no extras" do
    expected_ids = MapSet.new(@monk_skills, & &1.id)

    discovered_ids =
      Catalog.all()
      |> Enum.filter(&(&1.id in expected_ids))
      |> MapSet.new(& &1.id)

    assert discovered_ids == expected_ids
    assert MapSet.size(expected_ids) == 17
  end

  test "every Monk definition carries its correct id, display name, max level, target type, and capability" do
    Enum.each(@monk_skills, fn %{
                                 name: name,
                                 id: id,
                                 display_name: display_name,
                                 max_level: max_level,
                                 target_type: target_type,
                                 capability: capability
                               } ->
      assert {:ok, definition} = Catalog.by_name(name)
      assert definition.id == id
      assert definition.display_name == display_name
      assert definition.max_level == max_level
      assert definition.target_type == target_type
      assert {:ok, module} = module_for(capability, name)
      assert capability in module.__skill_capabilities__()
    end)
  end

  test "the four passive Monk mastery/proc skills are discovered as passive" do
    passives = ~w(mo_ironhand mo_spiritsrecovery mo_tripleattack mo_dodge)a

    for name <- passives do
      assert {:ok, _module} = Catalog.passive_module_for(name)
      assert :error = Catalog.active_module_for(name)
    end
  end

  test "Raging Trifecta Blow is the only Monk passive offering an attack replacement" do
    other_passives = ~w(mo_ironhand mo_spiritsrecovery mo_dodge)a

    {:ok, tripleattack} = Catalog.passive_module_for(:mo_tripleattack)
    assert function_exported?(tripleattack, :attack_replacement, 2)

    for name <- other_passives do
      {:ok, module} = Catalog.passive_module_for(name)
      refute function_exported?(module, :attack_replacement, 2)
    end
  end

  test "the thirteen active Monk skills are discovered as active, not passive" do
    actives = ~w(
      mo_callspirits mo_absorbspirits mo_bodyrelocation mo_investigate
      mo_fingeroffensive mo_steelbody mo_bladestop mo_explosionspirits
      mo_extremityfist mo_chaincombo mo_combofinish mo_kitranslation
      mo_balkyoung
    )a

    for name <- actives do
      assert {:ok, _module} = Catalog.active_module_for(name)
      assert :error = Catalog.passive_module_for(name)
    end
  end

  defp module_for(:active, name), do: Catalog.active_module_for(name)
  defp module_for(:passive, name), do: Catalog.passive_module_for(name)
end
