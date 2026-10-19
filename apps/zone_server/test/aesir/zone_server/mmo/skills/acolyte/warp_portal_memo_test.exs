defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.WarpPortalMemoTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.Mmo.Skill.WarpPortalMemo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.Stats.PlayerProgression

  test "remembering promotes the current map and evicts only the oldest different map" do
    player = %PlayerState{
      character_id: 1,
      map_name: "prontera",
      x: 120,
      y: 130,
      action_state: :idle,
      stats: %Stats{progression: %PlayerProgression{learned_skills: %{27 => 4}}},
      memo_points: [
        %{"map" => "izlude", "x" => 10, "y" => 20},
        %{"map" => "prontera", "x" => 30, "y" => 40},
        %{"map" => "morocc", "x" => 50, "y" => 60}
      ]
    }

    assert {:ok, remembered} =
             WarpPortalMemo.remember(player, MapData.new("prontera", 200, 200), %{})

    assert remembered.memo_points == [
             %{"map" => "prontera", "x" => 120, "y" => 130},
             %{"map" => "izlude", "x" => 10, "y" => 20},
             %{"map" => "morocc", "x" => 50, "y" => 60}
           ]
  end

  test "memo skill/map refusals do not shift points and warp permission bypasses map flags" do
    map = MapData.new("prontera", 200, 200)

    caster = %PlayerState{
      map_name: "prontera",
      x: 10,
      y: 20,
      action_state: :idle,
      stats: %Stats{progression: %PlayerProgression{learned_skills: %{27 => 1}}}
    }

    assert {:error, :insufficient_level, ^caster} = WarpPortalMemo.remember(caster, map, %{})
    learned = put_in(caster.stats.progression.learned_skills, %{27 => 2})

    for flag <- [:nomemo, :nowarpto] do
      assert {:error, :memo_forbidden, ^learned} =
               WarpPortalMemo.remember(learned, map, %{flag => true})

      assert {:ok, allowed} =
               WarpPortalMemo.remember(learned, map, %{flag => true, :any_warp => true})

      assert allowed.memo_points == [%{"map" => "prontera", "x" => 10, "y" => 20}]
    end
  end

  test "an instance refusal retains the source's already-shifted prefix" do
    first = %{"map" => "izlude", "x" => 1, "y" => 2}
    second = %{"map" => "morocc", "x" => 3, "y" => 4}

    caster = %PlayerState{
      map_name: "prontera",
      action_state: :idle,
      stats: %Stats{progression: %PlayerProgression{learned_skills: %{27 => 2}}},
      memo_points: [first, second, %{"map" => "geffen", "x" => 5, "y" => 6}]
    }

    map = %{MapData.new("prontera", 200, 200) | instance_id: 1}
    assert {:error, :instance_map, shifted} = WarpPortalMemo.remember(caster, map, %{})
    assert shifted.memo_points == [first, first, second]
  end
end
