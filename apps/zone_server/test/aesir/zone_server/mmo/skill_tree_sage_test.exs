defmodule Aesir.ZoneServer.Mmo.SkillTreeSageTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.DataLoader
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry

  @not_yet_implemented ~w(
    SA_ADVANCEDBOOK SA_CASTCANCEL SA_MAGICROD SA_SPELLBREAKER SA_FREECAST
    SA_AUTOSPELL SA_FLAMELAUNCHER SA_FROSTWEAPON SA_LIGHTNINGLOADER
    SA_SEISMICWEAPON SA_DRAGONOLOGY SA_VOLCANO SA_DELUGE SA_VIOLENTGALE
    SA_LANDPROTECTOR SA_DISPELL SA_CREATECON SA_ELEMENTWATER SA_ELEMENTGROUND
    SA_ELEMENTFIRE SA_ELEMENTWIND
  )

  @implemented_wz ~w(WZ_ESTIMATION WZ_EARTHSPIKE WZ_HEAVENDRIVE)

  test "boots without an unknown job warning for sage" do
    assert {:ok, _job_id} = AvailableJobs.job_name_to_id(:sage)
  end

  test "the loaded sage tree resolves only the currently-implemented WZ_* skills" do
    {:ok, sage_id} = AvailableJobs.job_name_to_id(:sage)

    resolved_names =
      sage_id
      |> SkillTree.tree_for()
      |> Map.values()
      |> Enum.filter(&(&1.owner_job_id == sage_id))
      |> Enum.map(fn %Entry{skill_id: skill_id} ->
        {:ok, definition} = Catalog.by_id(skill_id)
        definition.name |> Atom.to_string() |> String.upcase()
      end)
      |> MapSet.new()

    assert resolved_names == MapSet.new(@implemented_wz)
  end

  test "every sage tree entry either resolves or is a known not-yet-implemented SA_* skill" do
    path = Path.join(Application.app_dir(:zone_server, "priv/db/skill_tree"), "sage.yml")
    [%{"tree" => tree}] = DataLoader.parse_file(path)

    known = MapSet.new(@implemented_wz ++ @not_yet_implemented)

    Enum.each(tree, fn entry ->
      name = entry["name"]
      assert MapSet.member?(known, name), "unexpected sage tree entry #{inspect(name)}"

      case name |> String.downcase() |> String.to_atom() |> Catalog.by_name() do
        {:ok, _definition} -> assert name in @implemented_wz
        :error -> assert name in @not_yet_implemented
      end
    end)
  end
end
