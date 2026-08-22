defmodule Aesir.ZoneServer.Navigation.TargetTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.Navigation.Exclusions
  alias Aesir.ZoneServer.Navigation.SpawnIndex
  alias Aesir.ZoneServer.Navigation.Target
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  defmodule WaypointNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 150, y: 150, sprite: 58, name: "Guide"},
        %{map: "geffen", x: 75, y: 75, sprite: 58, name: "Guide"},
        %{map: "geffen", x: 75, y: 75, sprite: 58, name: "Guide"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule LabelNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "morocc", x: 100, y: 100, sprite: 58, name: "Navigator"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnNavigate", ctx), do: ctx
  end

  defmodule RestrictedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "aldeg_cas01", x: 100, y: 100, sprite: 58, name: "Restricted"},
        %{map: "prontera", x: 100, y: 100, sprite: 58, name: "Restricted"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  setup do
    setup_ets_tables(%{})
    :ok = Exclusions.reload()
    Registry.reload([WaypointNpc, LabelNpc, RestrictedNpc])
    on_exit(fn -> :persistent_term.erase(Registry) end)
    :ok
  end

  test "resolves a coordinate target to its single candidate" do
    assert Target.resolve({:coord, "prontera", 150, 150}, player("geffen")) ==
             {:ok, [{"prontera", {150, 150}}]}
  end

  test "resolves every named NPC placement without duplicate cells" do
    assert Target.resolve({:npc, "Guide"}, player("morocc")) ==
             {:ok, [{"prontera", {150, 150}}, {"geffen", {75, 75}}]}
  end

  test "resolves every spawning map for a monster" do
    expected = SpawnIndex.maps_for_mob(1002) |> MapSet.new()

    assert {:ok, candidates} = Target.resolve({:monster, 1002}, player("prontera"))
    assert MapSet.new(candidates) == MapSet.new(Enum.map(expected, &{&1, :any}))
  end

  test "resolves a map target unless the player is already there" do
    assert Target.resolve({:map, "geffen"}, player("prontera")) == {:ok, [{"geffen", :any}]}
    assert Target.resolve({:map, "prontera"}, player("prontera")) == {:error, :already_there}
  end

  test "falls back to event-label placements when no NPC name matches" do
    assert Target.resolve({:npc, "OnNavigate"}, player("prontera")) ==
             {:ok, [{"morocc", {100, 100}}]}
  end

  test "returns unresolved for unknown targets" do
    assert Target.resolve({:coord, "unknown_map", 1, 1}, player("prontera")) ==
             {:error, :unresolved}

    assert Target.resolve({:npc, "UnknownNpc"}, player("prontera")) == {:error, :unresolved}
    assert Target.resolve({:monster, 999_999}, player("prontera")) == {:error, :unresolved}
  end

  test "drops excluded candidates and distinguishes an all-excluded target" do
    assert Target.resolve({:npc, "Restricted"}, player("morocc")) ==
             {:ok, [{"prontera", {100, 100}}]}

    assert Target.resolve({:map, "aldeg_cas01"}, player("morocc")) == {:error, :excluded}
  end

  defp player(map_name), do: %PlayerState{map_name: map_name}
end
