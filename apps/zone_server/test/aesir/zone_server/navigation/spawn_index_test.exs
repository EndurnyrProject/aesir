defmodule Aesir.ZoneServer.Navigation.SpawnIndexTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Aesir.ZoneServer.Factory
  import Mimic

  alias Aesir.ZoneServer.DbTestSetup
  alias Aesir.ZoneServer.Mmo.MobManagement.Mobs
  alias Aesir.ZoneServer.Mmo.MobManagement.Spawns
  alias Aesir.ZoneServer.Navigation.SpawnIndex

  setup :set_mimic_from_context

  setup do
    setup_ets_tables(%{})
    :persistent_term.erase(SpawnIndex)
    on_exit(fn -> :persistent_term.erase(SpawnIndex) end)
    :ok
  end

  test "the first lookup returns all distinct maps for a mob and none for an absent mob" do
    poring = build(:mob_spawn, mob: 1002)
    other = build(:mob_spawn, mob: 1003)

    stub(Spawns, :all, fn ->
      %{"field_a" => [poring, poring, other], "field_b" => [poring], "field_c" => [other]}
    end)

    assert Enum.sort(SpawnIndex.maps_for_mob(1002)) == ["field_a", "field_b"]
    assert SpawnIndex.maps_for_mob(1004) == []
  end

  @tag :tmp_dir
  test "rebuilds after spawn data reload", %{tmp_dir: root} do
    assert {:ok, _} = Mobs.by_id(1002)

    on_exit(fn ->
      :ok = Spawns.reload()
      :ok = SpawnIndex.reload()
    end)

    {:ok, tmp_dir: directory} = DbTestSetup.configure_root(%{tmp_dir: root}, "spawns")
    path = Path.join(directory, "spawns.yml")

    File.write!(path, spawns_yaml("before"))
    :ok = Spawns.reload()
    :ok = SpawnIndex.reload()
    assert SpawnIndex.maps_for_mob(1002) == ["before"]

    File.write!(path, spawns_yaml("after"))
    File.rm!(Path.join(directory, ".cache/spawns_v2.etf"))
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
