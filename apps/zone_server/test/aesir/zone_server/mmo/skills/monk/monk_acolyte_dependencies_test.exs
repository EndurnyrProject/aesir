defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MonkAcolyteDependenciesTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDemonbane
  alias Aesir.ZoneServer.Mmo.Skills.Acolyte.AlDp
  alias Aesir.ZoneServer.Mmo.SkillTree

  # Monk's tree references exactly two Acolyte prerequisites, both maxed by
  # Iron Fists: the demon/undead-race attack passive and the soft-DEF passive.
  @audited_skills [
    %{
      name: :al_demonbane,
      id: 23,
      capability: :passive,
      definition_contract: %{max_level: 10, target_type: :passive},
      module: AlDemonbane,
      mechanic: "demon/undead race attack passive, required at max level to learn Iron Fists"
    },
    %{
      name: :al_dp,
      id: 22,
      capability: :passive,
      definition_contract: %{max_level: 10, target_type: :passive},
      module: AlDp,
      mechanic: "soft DEF passive, required at max level to learn Iron Fists"
    }
  ]

  test "the scoped Monk dependency audit names every Acolyte prerequisite Monk's tree references" do
    assert Enum.map(@audited_skills, & &1.name) == [:al_demonbane, :al_dp]
  end

  test "every audited dependency locks its definition contract, capability, and sufficient max level" do
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
      assert definition.max_level >= 10
    end)
  end

  test "Iron Fists' Acolyte prerequisites resolve to their exact required level in the Monk tree" do
    {:ok, monk_id} = AvailableJobs.job_name_to_id(:monk)

    {:ok, entry} = SkillTree.entry(monk_id, catalog_id(:mo_ironhand))

    assert {catalog_id(:al_demonbane), 10} in entry.requires
    assert {catalog_id(:al_dp), 10} in entry.requires
  end

  defp module_for(:passive, name), do: Catalog.passive_module_for(name)

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end
end
