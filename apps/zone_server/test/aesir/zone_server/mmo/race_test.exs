defmodule Aesir.ZoneServer.Mmo.RaceTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.Importer
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @tag game_mode: :renewal
  test "Renewal unit and combat views both report human-player race" do
    assert_player_race(:player_human)
  end

  @tag game_mode: :pre_renewal
  test "pre-renewal unit and combat views both report demi-human race" do
    assert_player_race(:demi_human)
  end

  defp assert_player_race(race) do
    state =
      PlayerState.new(%Character{
        id: 1,
        name: "RaceTest",
        account_id: 1,
        last_map: "prontera",
        last_x: 100,
        last_y: 100,
        base_level: 1,
        job_level: 1,
        class: 0,
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        hp: 100,
        max_hp: 100,
        sp: 50,
        max_sp: 50,
        status_point: 0,
        skill_point: 0
      })

    assert PlayerState.get_race(state) == race
    assert PlayerState.get_entity_info(state).race == race
    assert PlayerState.to_combatant(state).race == race
  end

  @tag game_mode: :renewal
  test "shipped player training dummies retain their distinct races" do
    assert {:ok, %{race: :player_human}} = Mobs.by_id(21_087)
    assert {:ok, %{race: :player_doram}} = Mobs.by_id(21_088)
  end

  test "ambiguous player and non-race classifications are rejected by the importer" do
    for race <- ["Player", "Human", "Beast", "Boss"] do
      entry = %{"Id" => 1, "AegisName" => "DUMMY", "Name" => "Dummy", "Race" => race}

      assert {:error, {:unknown_race, ^race}} = Importer.to_definition(entry)
    end
  end

  test "mob imports preserve human-player and Doram-player races" do
    for {source_race, race} <- [{"Player_Human", :player_human}, {"Player_Doram", :player_doram}] do
      entry = %{"Id" => 1, "AegisName" => "DUMMY", "Name" => "Dummy", "Race" => source_race}

      assert {:ok, definition} = Importer.to_definition(entry)
      assert definition.race == race
      assert Importer.to_yaml_map(definition)["race"] == Atom.to_string(race)
    end
  end
end
