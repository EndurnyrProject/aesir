defmodule Aesir.ZoneServer.Mmo.QuestManagement.LoaderTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.QuestManagement.Loader
  alias Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition

  setup context do
    Aesir.ZoneServer.DbTestSetup.configure_root(context, "quests")
  end

  @quests_yaml """
  - id: 1000
    title: Transcend
  - id: 7393
    title: Shiny Silver Blade
    targets:
      - mob_id: 2314
        count: 10
      - mob_id: 2311
        count: 10
  """

  defp write_yaml(dir, contents) do
    path = Path.join(dir, "quests.yml")
    File.write!(path, contents)
    path
  end

  describe "load/1" do
    @tag :tmp_dir
    test "parses our-schema YAML into an index by id", %{tmp_dir: dir} do
      write_yaml(dir, @quests_yaml)

      assert %{all: all, by_id: by_id} = Loader.load()
      assert length(all) == 2

      assert %QuestDefinition{id: 1000, title: "Transcend", targets: [], drops: []} =
               Map.fetch!(by_id, 1000)
    end

    @tag :tmp_dir
    test "a quest with no targets loads an empty targets list", %{tmp_dir: dir} do
      write_yaml(dir, @quests_yaml)

      assert %{by_id: %{1000 => %QuestDefinition{targets: []}}} = Loader.load()
    end

    @tag :tmp_dir
    test "a quest with multiple targets parses mob_id and count for each", %{tmp_dir: dir} do
      write_yaml(dir, @quests_yaml)

      assert %{by_id: %{7393 => %QuestDefinition{targets: targets}}} = Loader.load()

      assert targets == [
               %{mob_id: 2314, count: 10},
               %{mob_id: 2311, count: 10}
             ]
    end

    @tag :tmp_dir
    test "dormant fields (time_limit, filters, drops) are carried through", %{tmp_dir: dir} do
      write_yaml(dir, """
      - id: 7406
        title: Agree to Collecting Bones!
        time_limit: "24h"
        drops:
          - mob_id: 2309
            item_id: 6507
            count: 1
            rate: 5000
      - id: 7432
        title: The troublemakers in the land of blooming flowers
        targets:
          - mob_id: 1001
            count: 5
            min_level: 10
            max_level: 20
            race: brute
            size: medium
            element: fire
            map: prontera
            mobs_allowed: [1001, 1002]
      """)

      assert %{by_id: by_id} = Loader.load()

      assert %QuestDefinition{
               time_limit: "24h",
               drops: [%{mob_id: 2309, item_id: 6507, count: 1, rate: 5000}]
             } = Map.fetch!(by_id, 7406)

      assert %QuestDefinition{
               targets: [
                 %{
                   mob_id: 1001,
                   count: 5,
                   min_level: 10,
                   max_level: 20,
                   race: "brute",
                   size: "medium",
                   element: "fire",
                   map: "prontera",
                   mobs_allowed: [1001, 1002]
                 }
               ]
             } = Map.fetch!(by_id, 7432)
    end

    @tag :tmp_dir
    test "time_limit defaults to nil when not present", %{tmp_dir: dir} do
      write_yaml(dir, @quests_yaml)

      assert %{by_id: %{1000 => %QuestDefinition{time_limit: nil}}} = Loader.load()
    end

    @tag :tmp_dir
    test "writes a reusable .etf cache", %{tmp_dir: dir} do
      write_yaml(dir, @quests_yaml)
      Loader.load()

      assert File.exists?(Path.join([dir, ".cache", "quests.etf"]))
    end

    @tag :tmp_dir
    test "reuses the cache while it is newer than the sources", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @quests_yaml)
      Loader.load()

      cache = Path.join([dir, ".cache", "quests.etf"])
      File.write!(yaml, String.replace(@quests_yaml, "Transcend", "Renamed"))
      File.touch!(yaml, 1_000_000)
      File.touch!(cache, 2_000_000)

      assert %{by_id: %{1000 => %QuestDefinition{title: "Transcend"}}} = Loader.load()
    end

    @tag :tmp_dir
    test "rebuilds when a source is newer than the cache", %{tmp_dir: dir} do
      yaml = write_yaml(dir, @quests_yaml)
      Loader.load()

      cache = Path.join([dir, ".cache", "quests.etf"])
      File.write!(yaml, String.replace(@quests_yaml, "Transcend", "Renamed"))
      File.touch!(cache, 1_000_000)
      File.touch!(yaml, 2_000_000)

      assert %{by_id: %{1000 => %QuestDefinition{title: "Renamed"}}} = Loader.load()
    end

    @tag :tmp_dir
    test "raises when the domain has no base data", %{tmp_dir: _dir} do
      assert_raise RuntimeError, ~r/no renewal data for db "quests"/, fn ->
        Loader.load()
      end
    end
  end
end
