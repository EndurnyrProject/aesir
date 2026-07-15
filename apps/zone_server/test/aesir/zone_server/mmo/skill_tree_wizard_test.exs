defmodule Aesir.ZoneServer.Mmo.SkillTreeWizardTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  {:ok, mage_id} = AvailableJobs.job_name_to_id(:mage)
  @mage_id mage_id

  {:ok, wizard_id} = AvailableJobs.job_name_to_id(:wizard)
  @wizard_id wizard_id

  @rathena_wizard_tree "rAthena db/re/skill_tree.yml:475-550"

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  defp wizard_source do
    path = Application.app_dir(:zone_server, "priv/db/skill_tree/wizard.yml")
    [wizard] = DataLoader.parse_file(path)
    wizard
  end

  defp wizard_progression(attrs) do
    Map.merge(
      %PlayerProgression{
        base_level: 99,
        job_level: 50,
        base_exp: 0,
        job_exp: 0,
        job_id: @wizard_id,
        skill_point: 1,
        status_point: 0,
        learned_skills: %{}
      },
      Map.new(attrs)
    )
  end

  setup do
    :ok = Catalog.reload()
    :ok = SkillTree.reload()
  end

  test "Wizard tree exposes the nine staged skills with canonical prerequisites" do
    mage_ids = @mage_id |> SkillTree.tree_for() |> Map.keys() |> MapSet.new()
    wizard_tree = SkillTree.tree_for(@wizard_id)

    own_entries =
      wizard_tree
      |> Map.drop(MapSet.to_list(mage_ids))
      |> Map.new(fn {skill_id, entry} -> {skill_id, {entry.max_level, entry.requires}} end)

    assert own_entries == %{
             catalog_id(:wz_firepillar) => {10, [{catalog_id(:mg_firewall), 1}]},
             catalog_id(:wz_sightrasher) =>
               {10, [{catalog_id(:mg_lightningbolt), 1}, {catalog_id(:mg_sight), 1}]},
             catalog_id(:wz_jupitel) =>
               {10, [{catalog_id(:mg_napalmbeat), 1}, {catalog_id(:mg_lightningbolt), 1}]},
             catalog_id(:wz_vermilion) =>
               {10, [{catalog_id(:mg_thunderstorm), 1}, {catalog_id(:wz_jupitel), 5}]},
             catalog_id(:wz_frostnova) => {10, []},
             catalog_id(:wz_stormgust) =>
               {10, [{catalog_id(:mg_frostdiver), 1}, {catalog_id(:wz_jupitel), 3}]},
             catalog_id(:wz_earthspike) => {5, [{catalog_id(:mg_stonecurse), 1}]},
             catalog_id(:wz_heavendrive) => {5, [{catalog_id(:wz_earthspike), 3}]},
             catalog_id(:wz_quagmire) => {5, [{catalog_id(:wz_heavendrive), 1}]}
           },
           @rathena_wizard_tree
  end

  test "every staged Wizard entry and prerequisite name resolves through the catalog" do
    entries = wizard_source()["tree"]

    assert MapSet.new(entries, & &1["name"]) ==
             MapSet.new(~w(
               WZ_FIREPILLAR
               WZ_SIGHTRASHER
               WZ_JUPITEL
               WZ_VERMILION
               WZ_FROSTNOVA
               WZ_STORMGUST
               WZ_EARTHSPIKE
               WZ_HEAVENDRIVE
               WZ_QUAGMIRE
             ))

    catalog_names = MapSet.new(Catalog.all(), &(Atom.to_string(&1.name) |> String.upcase()))

    for entry <- entries,
        name <- [entry["name"] | Enum.map(entry["requires"] || [], & &1["name"])] do
      assert name in catalog_names, "expected #{name} to resolve through Skill.Catalog"
    end

    refute Enum.any?(entries, &(&1["name"] in ["WZ_ESTIMATION", "WZ_SIGHTBLASTER"]))
    assert :error = Catalog.by_name(:wz_estimation)
    assert :error = Catalog.by_name(:wz_sightblaster)
  end

  test "Frost Nova defers WZ_ICEWALL 1 until Task 27 registers both atomically" do
    assert SkillTree.tree_for(@wizard_id)[catalog_id(:wz_frostnova)].requires == []

    frost_nova = Enum.find(wizard_source()["tree"], &(&1["name"] == "WZ_FROSTNOVA"))
    refute Map.has_key?(frost_nova, "requires")
  end

  test "Heaven's Drive requires Earth Spike level 3" do
    heaven_drive = catalog_id(:wz_heavendrive)
    earth_spike = catalog_id(:wz_earthspike)

    assert {:error, :missing_prerequisite} =
             SkillTree.can_learn(
               wizard_progression(learned_skills: %{earth_spike => 2}),
               heaven_drive
             )

    assert :ok =
             SkillTree.can_learn(
               wizard_progression(learned_skills: %{earth_spike => 3}),
               heaven_drive
             )
  end
end
