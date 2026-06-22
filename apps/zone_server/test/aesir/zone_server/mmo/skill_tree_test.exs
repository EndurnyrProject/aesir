defmodule Aesir.ZoneServer.Mmo.SkillTreeTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.SkillTree
  alias Aesir.ZoneServer.Mmo.SkillTree.Entry

  {:ok, swordman_id} = AvailableJobs.job_name_to_id(:swordman)
  @swordman_id swordman_id

  defp catalog_id(name) do
    {:ok, definition} = Catalog.by_name(name)
    definition.id
  end

  describe "tree_for/1 (real data)" do
    test "Swordman tree contains all implemented sm_* entries" do
      tree = SkillTree.tree_for(@swordman_id)

      for name <- [
            :sm_sword,
            :sm_twohand,
            :sm_recovery,
            :sm_bash,
            :sm_provoke,
            :sm_magnum,
            :sm_endure,
            :sm_movingrecovery,
            :sm_fatalblow,
            :sm_autoberserk
          ] do
        assert Map.has_key?(tree, catalog_id(name)), "expected #{name} in Swordman tree"
      end
    end

    test "sm_twohand requires sm_sword at level 1" do
      {:ok, %Entry{requires: requires}} =
        SkillTree.entry(@swordman_id, catalog_id(:sm_twohand))

      assert requires == [{catalog_id(:sm_sword), 1}]
    end

    test "sm_sword caps at the rAthena max level of 10" do
      {:ok, %Entry{max_level: max_level}} =
        SkillTree.entry(@swordman_id, catalog_id(:sm_sword))

      assert max_level == 10
    end

    test "inherited Novice skills are filtered out (none implemented)" do
      tree = SkillTree.tree_for(@swordman_id)
      assert map_size(tree) == 10
    end

    test "entry/2 returns :error for a skill not in the job tree" do
      assert :error = SkillTree.entry(@swordman_id, 999_999)
    end

    test "tree_for/1 returns an empty map for an unknown job" do
      assert SkillTree.tree_for(999_999) == %{}
    end
  end

  describe "reload/0" do
    test "rebuilds the index" do
      assert :ok = SkillTree.reload()
      assert map_size(SkillTree.tree_for(@swordman_id)) == 10
    end
  end

  describe "flatten_inherit/1 (pure, fixture data)" do
    test "child inherits a parent's entry" do
      raw = %{
        "parent" => [%{"name" => "P_SKILL", "max_level" => 5}],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "C_SKILL", "max_level" => 3}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)

      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"]) |> Enum.sort()
      assert names == ["C_SKILL", "P_SKILL"]
    end

    test "child override of an inherited skill wins" do
      raw = %{
        "parent" => [%{"name" => "P_SKILL", "max_level" => 5}],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "P_SKILL", "max_level" => 1}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      [entry] = Map.fetch!(flattened, "child")

      assert entry["name"] == "P_SKILL"
      assert entry["max_level"] == 1
    end

    test "child excludes an inherited skill" do
      raw = %{
        "parent" => [
          %{"name" => "P_KEEP", "max_level" => 5},
          %{"name" => "P_DROP", "max_level" => 5}
        ],
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "P_DROP", "max_level" => 1, "exclude" => true}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"])

      assert names == ["P_KEEP"]
    end

    test "inheritance is transitive across chains" do
      raw = %{
        "grandparent" => [%{"name" => "G_SKILL", "max_level" => 5}],
        "parent" => %{
          inherit: ["grandparent"],
          tree: [%{"name" => "P_SKILL", "max_level" => 5}]
        },
        "child" => %{
          inherit: ["parent"],
          tree: [%{"name" => "C_SKILL", "max_level" => 5}]
        }
      }

      flattened = SkillTree.flatten_inherit(raw)
      names = flattened |> Map.fetch!("child") |> Enum.map(& &1["name"]) |> Enum.sort()

      assert names == ["C_SKILL", "G_SKILL", "P_SKILL"]
    end
  end

  describe "Catalog filtering" do
    test "AL_INCAGI is kept but its unimplemented prerequisite (AL_HEAL) is dropped" do
      {:ok, acolyte_id} = AvailableJobs.job_name_to_id(:acolyte)

      {:ok, %Entry{requires: requires}} =
        SkillTree.entry(acolyte_id, catalog_id(:al_incagi))

      assert requires == []
    end

    test "warns when a tree entry names an unimplemented skill" do
      log =
        capture_log(fn ->
          SkillTree.reload()
        end)

      assert log =~ "NV_BASIC"
    end
  end
end
