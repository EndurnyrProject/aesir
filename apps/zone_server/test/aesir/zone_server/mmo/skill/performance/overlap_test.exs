defmodule Aesir.ZoneServer.Mmo.Skill.Performance.OverlapTest do
  use ExUnit.Case, async: true

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Mmo.Skill.Performance.Overlap
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  setup :setup_ets_tables

  test "two songs are dissonant exactly on their shared cells until the other is deleted" do
    first = group(1, :song, [{1, 1}, {2, 1}, {3, 1}])
    second = group(2, :song, [{2, 1}, {3, 1}, {4, 1}])
    :ok = Storage.insert(first)
    :ok = Storage.insert(second)

    assert Overlap.dissonant?(first, {2, 1})
    assert Overlap.dissonant?(first, {3, 1})
    refute Overlap.dissonant?(first, {1, 1})
    assert Overlap.dissonant?(second, {2, 1})
    refute Overlap.dissonant?(second, {4, 1})

    :ok = Storage.delete(2)
    refute Overlap.dissonant?(first, {2, 1})
  end

  test "a song and dance coexist, while two dances overlap" do
    song = group(1, :song, [{1, 1}])
    dance = group(2, :dance, [{1, 1}])
    :ok = Storage.insert(song)
    :ok = Storage.insert(dance)
    refute Overlap.dissonant?(song, {1, 1})
    refute Overlap.dissonant?(dance, {1, 1})

    :ok = Storage.insert(group(3, :dance, [{1, 1}]))
    assert Overlap.dissonant?(dance, {1, 1})
    refute Overlap.dissonant?(song, {1, 1})
  end

  test "ensembles and ordinary ground skills never contribute to dissonance" do
    song = group(1, :song, [{1, 1}])
    ensemble = group(2, :ensemble, [{1, 1}])
    ordinary = %{group(3, :song, [{1, 1}]) | state: %{}}
    for group <- [song, ensemble, ordinary], do: Storage.insert(group)

    refute Overlap.dissonant?(ordinary, {1, 1})
    refute Overlap.dissonant?(song, {1, 1})
    refute Overlap.dissonant?(ensemble, {1, 1})
  end

  test "three songs keep the cell dissonant while any other remains" do
    groups = for id <- 1..3, do: group(id, :song, [{1, 1}])
    Enum.each(groups, &Storage.insert/1)
    assert Enum.all?(groups, &Overlap.dissonant?(&1, {1, 1}))

    :ok = Storage.delete(2)
    assert Overlap.dissonant?(hd(groups), {1, 1})
    :ok = Storage.delete(3)
    refute Overlap.dissonant?(hd(groups), {1, 1})
  end

  defp group(id, kind, cells) do
    %Group{
      group_id: id,
      skill_name: :performance,
      map_name: "prontera",
      cells: cells,
      state: %{performance: %{kind: kind}}
    }
  end
end
