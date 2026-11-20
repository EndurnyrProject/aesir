defmodule Aesir.ZoneServer.Mmo.QuestManagement.LoaderTest do
  use ExUnit.Case, async: true

  import Aesir.ZoneServer.Factory

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.QuestManagement.Loader

  @moduletag :tmp_dir

  setup context, do: DbTestSetup.configure_root(context, "quests")

  test "decodes quest YAML, including defaults and ordered objectives", %{tmp_dir: dir} do
    File.write!(Path.join(dir, "quests.yml"), """
    - id: 10
      title: Introduction
    - id: 20
      title: Hunt
      time_limit: "24h"
      targets:
        - mob_id: 2314
          count: 10
        - count: 5
          min_level: 10
          max_level: 20
          race: brute
          size: medium
          element: fire
          map: prontera
          mobs_allowed: [1001, 1002]
      drops:
        - mob_id: 2309
          item_id: 6507
          count: 1
          rate: 5000
    """)

    intro = build(:quest_definition, id: 10, title: "Introduction")

    hunt =
      build(:quest_definition,
        id: 20,
        title: "Hunt",
        time_limit: "24h",
        targets: [
          %{mob_id: 2314, count: 10},
          %{
            count: 5,
            min_level: 10,
            max_level: 20,
            race: "brute",
            size: "medium",
            element: "fire",
            map: "prontera",
            mobs_allowed: [1001, 1002]
          }
        ],
        drops: [%{mob_id: 2309, item_id: 6507, count: 1, rate: 5000}]
      )

    assert %{by_id: %{10 => ^intro, 20 => ^hunt}} = Loader.load()
  end

  test "raises when the domain has no base data" do
    assert_raise RuntimeError, ~r/no #{GameMode.mode()} data for db "quests"/, fn ->
      Loader.load()
    end
  end
end
