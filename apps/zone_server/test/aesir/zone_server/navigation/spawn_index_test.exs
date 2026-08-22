defmodule Aesir.ZoneServer.Navigation.SpawnIndexTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns
  alias Aesir.ZoneServer.Navigation.SpawnIndex

  setup do
    setup_ets_tables(%{})
    :persistent_term.erase(SpawnIndex)
    on_exit(fn -> :persistent_term.erase(SpawnIndex) end)
    :ok
  end

  test "returns every distinct map that spawns a mob" do
    expected_maps =
      Spawns.all()
      |> Enum.filter(fn {_map, spawns} -> Enum.any?(spawns, &(&1.mob == 1002)) end)
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    maps = SpawnIndex.maps_for_mob(1002)

    assert MapSet.new(maps) == expected_maps
    assert length(maps) == MapSet.size(expected_maps)
  end

  test "returns no maps for a mob with no spawns" do
    assert SpawnIndex.maps_for_mob(999_999) == []
  end

  test "warms on the first lookup" do
    assert :persistent_term.get(SpawnIndex, nil) == nil

    SpawnIndex.maps_for_mob(1002)

    assert %{} = :persistent_term.get(SpawnIndex, nil)
  end

  @tag :tmp_dir
  test "rebuilds after spawn data reload", %{tmp_dir: root} do
    assert {:ok, _} = Mobs.by_id(1002)

    on_exit(fn ->
      :ok = Spawns.reload()
      :ok = SpawnIndex.reload()
    end)

    {:ok, _} = DbTestSetup.configure_root(%{tmp_dir: root}, "spawns")
    path = Path.join(root, "re/spawns/spawns.yml")

    File.write!(path, spawns_yaml("before"))
    :ok = Spawns.reload()
    :ok = SpawnIndex.reload()
    assert SpawnIndex.maps_for_mob(1002) == ["before"]

    File.write!(path, spawns_yaml("after"))
    File.rm!(Path.join(root, "re/spawns/.cache/spawns_v2.etf"))
    :ok = Spawns.reload()
    assert SpawnIndex.maps_for_mob(1002) == ["before"]

    :ok = SpawnIndex.reload()
    assert SpawnIndex.maps_for_mob(1002) == ["after"]
  end

  defp spawns_yaml(map_name) do
    """
    - map: #{map_name}
      spawns:
        - mob: 1002
          amount: 1
          respawn_time: 1000
          area:
            x: 10
            y: 10
    """
  end
end
