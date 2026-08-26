defmodule Aesir.ZoneServer.Npc.RegistryTest do
  use ExUnit.Case, async: false
  import Mimic

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement
  alias Aesir.ZoneServer.Npc.Registry
  alias Aesir.ZoneServer.Npc.Session
  alias Aesir.ZoneServer.Npc.SessionDynamicSupervisor
  alias Aesir.ZoneServer.Npc.Verifier

  defmodule DiscoverableNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 199, y: 201, dir: 0, sprite: 58, name: "T"}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule CollidingNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 199, y: 201, dir: 0, sprite: 58, name: "C", unique_name: "T"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule NotAnNpc do
    def spawn, do: []
  end

  defmodule DuplicateNamedNpcA do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 10, y: 10, sprite: 58, name: "Guard", unique_name: "Guard#pt"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule DuplicateNamedNpcB do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 20, y: 20, sprite: 58, name: "Guard", unique_name: "Guard#pt"}
      ]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule EventedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 30, y: 30, sprite: 58, name: "Timer"}]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnTimer5000", ctx), do: ctx
  end

  defmodule TouchNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 50, y: 60, sprite: 58, name: "Trigger", trigger: {2, 1}}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule NamelessNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [%{map: "prontera", x: 40, y: 40, sprite: 58}]

    @impl true
    def on_talk(ctx), do: ctx
  end

  defmodule MultiPlacementEventedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{map: "prontera", x: 70, y: 70, sprite: 58, name: "A"},
        %{map: "prontera", x: 80, y: 80, sprite: 58, name: "B"}
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnSharedLabel", ctx), do: ctx
  end

  defmodule ModeScopedSharedNpc do
    use Aesir.ZoneServer.Npc,
      spawn: [
        %{
          map: "prontera",
          x: 100,
          y: 100,
          sprite: 58,
          name: "Shared",
          unique_name: "Mode#shared",
          trigger: {1, 1}
        },
        %{
          map: "prontera",
          x: 101,
          y: 101,
          sprite: 58,
          name: "Renewal Shared",
          unique_name: "Mode#shared",
          trigger: {1, 1},
          scope: :renewal
        },
        %{
          map: "prontera",
          x: 102,
          y: 102,
          sprite: 58,
          name: "Pre-Renewal Shared",
          unique_name: "Mode#shared",
          trigger: {1, 1},
          scope: :pre_renewal
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnMode", ctx), do: ctx
  end

  defmodule RenewalModeNpc do
    use Aesir.ZoneServer.Npc,
      scope: :renewal,
      spawn: [
        %{
          map: "prontera",
          x: 110,
          y: 110,
          sprite: 58,
          name: "Renewal",
          unique_name: "Mode#renewal",
          trigger: {1, 1}
        },
        %{
          map: "prontera",
          x: 111,
          y: 111,
          sprite: 58,
          name: "Inactive Placement",
          unique_name: "Mode#inactive",
          trigger: {1, 1},
          scope: :pre_renewal
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnMode", ctx), do: ctx
  end

  defmodule PreRenewalModeNpc do
    use Aesir.ZoneServer.Npc,
      scope: :pre_renewal,
      spawn: [
        %{
          map: "prontera",
          x: 120,
          y: 120,
          sprite: 58,
          name: "Pre-Renewal",
          unique_name: "Mode#pre_renewal",
          trigger: {1, 1}
        }
      ]

    @impl true
    def on_talk(ctx), do: ctx

    @impl true
    def on_event("OnMode", ctx), do: ctx
  end

  setup do
    on_exit(fn -> :persistent_term.erase(Registry) end)
    Registry.reload([DiscoverableNpc, NotAnNpc])
    :ok
  end

  describe "reload/1" do
    test "keeps only modules declaring the Npc behaviour" do
      modules = Enum.map(Registry.entries(), fn {mod, _} -> mod end)

      assert DiscoverableNpc in modules
      refute NotAnNpc in modules
    end

    test "terminates every running Npc.Session before rebuilding" do
      {DiscoverableNpc, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      pid = Session.ensure_started(gid)
      ref = Process.monitor(pid)

      Registry.reload([DiscoverableNpc, NotAnNpc])

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      assert DynamicSupervisor.which_children(SessionDynamicSupervisor) == []
      # SessionRegistry unregisters via its own monitor of the dead process, which
      # runs asynchronously after terminate_child returns, so wait for the entry
      # to clear rather than reading it on the same tick as the termination.
      assert wait_until_unregistered(gid)
    end
  end

  describe "reload/2" do
    test "builds every index from shared and active-mode content only" do
      modules = [ModeScopedSharedNpc, RenewalModeNpc, PreRenewalModeNpc]

      Registry.reload(modules, :renewal)

      assert_mode_indexes(
        [{ModeScopedSharedNpc, 100}, {ModeScopedSharedNpc, 101}, {RenewalModeNpc, 110}],
        [{ModeScopedSharedNpc, 102}, {RenewalModeNpc, 111}, {PreRenewalModeNpc, 120}],
        [100, 101]
      )

      Registry.reload(modules, :pre_renewal)

      assert_mode_indexes(
        [{ModeScopedSharedNpc, 100}, {ModeScopedSharedNpc, 102}, {PreRenewalModeNpc, 120}],
        [{ModeScopedSharedNpc, 101}, {RenewalModeNpc, 110}, {RenewalModeNpc, 111}],
        [100, 102]
      )
    end

    test "terminates every running Npc.Session before rebuilding" do
      Registry.reload([DiscoverableNpc], :renewal)
      {DiscoverableNpc, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      pid = Session.ensure_started(gid)
      ref = Process.monitor(pid)

      Registry.reload([DiscoverableNpc], :renewal)

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}
      assert DynamicSupervisor.which_children(SessionDynamicSupervisor) == []
      assert wait_until_unregistered(gid)
    end
  end

  defp assert_mode_indexes(active_entries, inactive_entries, shared_placement_xs) do
    assert Enum.map(Registry.entries(), fn {module, placement} -> {module, placement.x} end) ==
             active_entries

    for {module, x} <- active_entries do
      placement = placement_at(module, x)
      gid = Registry.entity_id(placement)

      assert {:ok, {^module, ^placement}} = Registry.module_at("prontera", x, x)
      assert {:ok, {^module, ^placement}} = Registry.module_for_unit(gid)
    end

    for {module, x} <- inactive_entries do
      placement = placement_at(module, x)

      assert :error = Registry.module_at("prontera", x, x)
      assert :error = Registry.module_for_unit(Registry.entity_id(placement))
    end

    assert Registry.by_name("Mode#shared")
           |> Enum.map(fn {module, placement} -> {module, placement.x} end) ==
             Enum.map(shared_placement_xs, &{ModeScopedSharedNpc, &1})

    assert Registry.entries_for_label("OnMode")
           |> Enum.map(fn {module, gid} ->
             assert {:ok, {^module, placement}} = Registry.module_for_unit(gid)
             {module, placement.x}
           end) == active_entries

    assert Registry.gids_for_label("OnMode") ==
             Enum.map(active_entries, fn {module, x} ->
               module |> placement_at(x) |> Registry.entity_id()
             end)

    assert Registry.touch_rects("prontera")
           |> Enum.map(fn {gid, _x_range, _y_range} -> gid end)
           |> Enum.map(fn gid ->
             {:ok, {module, placement}} = Registry.module_for_unit(gid)
             {module, placement.x}
           end) == active_entries
  end

  defp placement_at(module, x) do
    Enum.find(module.spawn(), &(&1.x == x))
  end

  defp wait_until_unregistered(gid, deadline \\ System.monotonic_time(:millisecond) + 500)

  defp wait_until_unregistered(gid, deadline) do
    case Elixir.Registry.lookup(Aesir.ZoneServer.Npc.SessionRegistry, gid) do
      [] ->
        true

      _still_registered ->
        if System.monotonic_time(:millisecond) < deadline do
          Process.sleep(5)
          wait_until_unregistered(gid, deadline)
        else
          false
        end
    end
  end

  describe "module_at/3" do
    test "resolves a discovered NPC's spawn cell to its module and placement" do
      assert {:ok, {DiscoverableNpc, %Placement{} = placement}} =
               Registry.module_at("prontera", 199, 201)

      assert placement.map == "prontera"
      assert placement.x == 199
      assert placement.y == 201
    end

    test "returns :error for a cell with no NPC" do
      assert :error = Registry.module_at("prontera", 1, 1)
    end
  end

  describe "entries/0" do
    test "lists discovered placements as un-collapsed {module, placement}" do
      assert {DiscoverableNpc, %Placement{}} =
               Enum.find(Registry.entries(), fn {mod, _} -> mod == DiscoverableNpc end)
    end

    test "keeps both NPCs on a shared cell so the verifier can flag the collision" do
      stub(MapCache, :walkable?, fn _, _, _ -> true end)
      Registry.reload([DiscoverableNpc, CollidingNpc])

      assert {:error, errors} = Verifier.verify(Registry.entries())
      assert Enum.any?(errors, &match?({:cell_collision, {"prontera", 199, 201}, _mods}, &1))
    end
  end

  describe "entity_id/1" do
    test "is deterministic for a placement and sits in the reserved NPC gid range" do
      {_module, placement} = hd(Registry.entries())

      gid = Registry.entity_id(placement)

      assert gid == Registry.entity_id(placement)
      assert gid in 0x5000_0000..0x57FF_FFFF
    end
  end

  describe "module_for_unit/1" do
    test "resolves a spawned NPC's unit id back to its module and placement" do
      {module, placement} = hd(Registry.entries())
      gid = Registry.entity_id(placement)

      assert {:ok, {^module, ^placement}} = Registry.module_for_unit(gid)
    end

    test "returns :error for a gid with no registered NPC" do
      assert :error = Registry.module_for_unit(0x5000_0000 - 1)
    end
  end

  describe "by_name/1" do
    test "resolves a unique name to every placement sharing it" do
      Registry.reload([DuplicateNamedNpcA, DuplicateNamedNpcB])

      entries = Registry.by_name("Guard#pt")

      assert length(entries) == 2
      assert Enum.any?(entries, fn {mod, _} -> mod == DuplicateNamedNpcA end)
      assert Enum.any?(entries, fn {mod, _} -> mod == DuplicateNamedNpcB end)
    end

    test "defaults unique_name to name when not declared" do
      assert [{DiscoverableNpc, placement}] = Registry.by_name("T")
      assert placement.unique_name == "T"
    end

    test "returns [] for an unknown name" do
      assert [] = Registry.by_name("nonexistent")
    end

    test "excludes placements with no name or unique_name from the index" do
      Registry.reload([NamelessNpc])

      assert [] = Registry.by_name("")
    end
  end

  describe "gids_for_label/1" do
    test "returns every gid whose module declares the label" do
      Registry.reload([EventedNpc])
      {_module, placement} = hd(Registry.entries())

      assert Registry.gids_for_label("OnTimer5000") == [Registry.entity_id(placement)]
    end

    test "returns [] for an unknown label" do
      assert [] = Registry.gids_for_label("OnNonexistent")
    end

    test "returns one gid per placement when multiple placements share a label" do
      Registry.reload([MultiPlacementEventedNpc])
      [{_module_a, placement_a}, {_module_b, placement_b}] = Registry.entries()

      gids = Registry.gids_for_label("OnSharedLabel")

      assert length(gids) == 2
      assert Registry.entity_id(placement_a) in gids
      assert Registry.entity_id(placement_b) in gids
    end
  end

  describe "touch_rects/1" do
    test "returns rects only for placements with a trigger set" do
      Registry.reload([TouchNpc])
      {_module, placement} = hd(Registry.entries())

      assert [{gid, x_range, y_range}] = Registry.touch_rects("prontera")
      assert gid == Registry.entity_id(placement)
      assert x_range == 48..52
      assert y_range == 59..61
    end

    test "returns [] for a map with no touch placements" do
      assert [] = Registry.touch_rects("prontera")
    end
  end
end
