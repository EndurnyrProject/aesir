defmodule Aesir.ZoneServer.Npc.Registry do
  @moduledoc """
  Boot-time, cascade-free index of bespoke NPC modules.

  At boot (`reload/0`), scans the `:zone_server` application's modules for those
  declaring the `Aesir.ZoneServer.Npc` behaviour, reads each module's `spawn/0`,
  and stores both the raw `[{module, placement}]` entries (for the
  `Aesir.ZoneServer.Npc.Verifier`) and a collapsed `{map, x, y} => {module,
  placement}` lookup index in `:persistent_term`. There is **no** compile-time
  central catalog: NPC modules are dependency-graph leaves, so adding or editing
  one never recompiles the engine — the runtime scan picks it up at the next
  boot.

  Lookups go through `module_at/3` (a spawn cell → its NPC module + placement);
  `entries/0` returns the un-collapsed list so the verifier can detect two NPCs
  sharing one cell (which the lookup index, last-write-wins, would hide).

  Each placement also gets a stable synthetic unit id (`entity_id/1`) so it can
  render to clients as a static NPC unit; `module_for_unit/1` reverses that id
  back to the owning module for click routing. Both are pure functions of the
  static placement set — there is no runtime, spawn-assigned id to track.

  Three further indexes support event-driven scripting: `by_name/1` resolves a
  placement's `unique_name` to every placement sharing it (rAthena duplicates
  legitimately share a name — `donpcevent` fires on each); `gids_for_label/1`
  resolves an event label to every gid whose module declares it in `events/0`
  (used by `trigger_all/1` and the clock scheduler); `touch_rects/1` lists the
  touch-area rects on a map, derived from placements with `trigger` set (used
  by movement's `OnTouch` check).
  """

  alias Aesir.ZoneServer.Npc
  alias Aesir.ZoneServer.Npc.Placement

  @pt_key __MODULE__
  @session_dynamic_supervisor Aesir.ZoneServer.Npc.SessionDynamicSupervisor

  # Reserved high gid range for static NPC entities, disjoint from every other
  # gid: mob `instance_id`s (2..1_999_999), player `character_id`s (low DB PKs),
  # floor item ids (hex *strings*, never integers), and warp entities
  # (`0x4000_0000` base, see `Npc.Warp.Registry`). `:erlang.phash2/1` yields
  # 0..2^27-1, so NPC gids span `0x5000_0000..0x57FF_FFFF`, within `uint32`
  # (the `UnitSpawn.gid` width). The gid keys on `{map, x, y, unique_name}`, so
  # NPCs stacked on one cell stay distinct as long as their unique names differ
  # (they always do — that is what `#name` targeting is for); the `Verifier`
  # surfaces only the degenerate case of a shared cell *and* unique name.
  @npc_entity_id_base 0x5000_0000

  @typedoc "A discovered NPC module paired with one of its placements."
  @type entry :: {module(), Placement.t()}

  @typedoc "Maps a spawn cell to the NPC module that owns it and its placement."
  @type index :: %{{String.t(), non_neg_integer(), non_neg_integer()} => entry()}

  @typedoc "Maps a placement's synthetic unit id to the NPC module that owns it."
  @type by_unit :: %{non_neg_integer() => entry()}

  @typedoc "Maps a unique name to every placement registered under it."
  @type by_name :: %{String.t() => [entry()]}

  @typedoc """
  Maps an event label to every `{module, gid}` whose module declares it in
  `events/0`. The declaring module is stored alongside the gid so dispatch
  never has to round-trip the gid back through `by_unit`, which collapses
  colliding cells (last placement at a `{map, x, y}` wins) and would otherwise
  route a label to the wrong module.
  """
  @type by_label :: %{String.t() => [{module(), non_neg_integer()}]}

  @typedoc "A touch-area rect: the owning gid plus its x and y ranges."
  @type touch_rect :: {non_neg_integer(), Range.t(), Range.t()}

  @typedoc "Maps a map name to its touch rects."
  @type touch_rects :: %{String.t() => [touch_rect()]}

  @typedoc """
  The stored registry: the raw entries plus the cell, unit, name, label, and
  touch-rect indexes.
  """
  @type registry :: %{
          entries: [entry()],
          index: index(),
          by_unit: by_unit(),
          by_name: by_name(),
          by_label: by_label(),
          touch_rects: touch_rects()
        }

  @doc """
  Rebuilds the registry from the given modules (default: the `:zone_server`
  application's modules), keeping only those declaring the `Npc` behaviour.

  First terminates every running `Npc.Session`, matching rAthena's
  `@reloadscript` behavior: a session surviving a reload could double-arm its
  timer when `Events.run_on_init/0` re-runs `OnInit`, or keep stale
  enabled/hidden flags for a placement that moved or disappeared. Stores the
  fresh registry in `:persistent_term`, replacing any previous one, and
  returns it. The `modules` argument is an injectable seam for tests, which
  pass their own in-file NPC modules.

  Does **not** run `OnInit` itself — callers that want rAthena's full
  `@reloadscript` semantics call `Events.run_on_init/0` afterwards.
  """
  @spec reload([module()]) :: registry()
  def reload(modules \\ default_app_modules()) do
    terminate_sessions()
    registry = build(npc_modules(modules))
    :persistent_term.put(@pt_key, registry)
    registry
  end

  @doc """
  Returns the NPC module and placement at `{map, x, y}`, or `:error` if none.
  """
  @spec module_at(String.t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, entry()} | :error
  def module_at(map, x, y), do: Map.fetch(registry().index, {map, x, y})

  @doc """
  Returns every registered `{module, placement}` pair, un-collapsed.

  This is what the verifier consumes: it preserves duplicate cells so a cell
  collision is detectable (`module_at/3`'s index collapses them, last wins).
  """
  @spec entries() :: [entry()]
  def entries, do: registry().entries

  @doc """
  Derives a stable synthetic unit id (`gid`) for a placement.

  A pure function of `{map, x, y, unique_name}` in the reserved NPC range: the
  same placement always resolves to the same gid across runs and nodes, with no
  process or registry write. Including `unique_name` — rAthena's per-NPC
  identity, the target of `donpcevent "Name#unique::OnLabel"` — means two NPCs
  legitimately stacked on the same cell (a visible guide plus an invisible
  `waitingroom` controller, say) each get their own gid and stay independently
  addressable, mirroring rAthena's running-counter ids rather than collapsing
  onto one.
  """
  @spec entity_id(Placement.t()) :: non_neg_integer()
  def entity_id(%Placement{} = placement) do
    @npc_entity_id_base +
      :erlang.phash2({placement.map, placement.x, placement.y, placement.unique_name})
  end

  @doc """
  Resolves a spawned NPC's unit id back to its module and placement.

  This is the click-routing seam: a client `NpcTalk` carries the unit id of the
  NPC it clicked, and the session resolves it through here to the NPC module.
  """
  @spec module_for_unit(non_neg_integer()) :: {:ok, entry()} | :error
  def module_for_unit(unit_id), do: Map.fetch(registry().by_unit, unit_id)

  @doc """
  Returns every placement registered under `unique_name`, or `[]` if none.

  A unique name may legitimately map to more than one placement — rAthena
  duplicates share a name — callers are expected to fire on each.
  """
  @spec by_name(String.t()) :: [entry()]
  def by_name(unique_name), do: Map.get(registry().by_name, unique_name, [])

  @doc """
  Returns every gid whose module declares `label` in its `events/0`, or `[]`
  if no module does.

  Gids are de-duplicated: when two colliding placements at the same cell both
  declare `label`, their shared gid appears once. Callers that must dispatch to
  the specific declaring module (not the one `by_unit` collapsed the cell to)
  should use `entries_for_label/1` instead.
  """
  @spec gids_for_label(String.t()) :: [non_neg_integer()]
  def gids_for_label(label) do
    registry().by_label
    |> Map.get(label, [])
    |> Enum.map(fn {_module, gid} -> gid end)
    |> Enum.uniq()
  end

  @doc """
  Returns every `{module, gid}` whose module declares `label` in its
  `events/0`, or `[]` if none does.

  Unlike `gids_for_label/1`, this preserves the declaring module for each gid,
  so event dispatch goes straight to the module that owns the label rather than
  re-resolving the gid through `by_unit` (which collapses colliding cells to a
  single module and would misroute the event).
  """
  @spec entries_for_label(String.t()) :: [{module(), non_neg_integer()}]
  def entries_for_label(label), do: Map.get(registry().by_label, label, [])

  @doc """
  Returns every distinct event label declared by a registered module's
  `events/0`.

  Used by `Aesir.ZoneServer.Npc.ClockScheduler` to find the clock-style
  labels (`OnClock*`, `OnHour*`, `OnMinute*`, `On<Ddd>*`) present at tick
  time, without scanning every module directly.
  """
  @spec labels() :: [String.t()]
  def labels, do: Map.keys(registry().by_label)

  @doc """
  Returns the touch rects on `map`, one per placement with a `trigger` set, or
  `[]` if none. Each rect is `{gid, x_range, y_range}`, the placement's cell
  expanded by the trigger's half-extents.
  """
  @spec touch_rects(String.t()) :: [touch_rect()]
  def touch_rects(map), do: Map.get(registry().touch_rects, map, [])

  # Guarded on the supervisor being started at all: many tests reload the
  # registry standalone, without booting the NPC session tree.
  @spec terminate_sessions() :: :ok
  defp terminate_sessions do
    supervisor =
      ProcessTree.get({@session_dynamic_supervisor, :server}) || @session_dynamic_supervisor

    resolved =
      case supervisor do
        pid when is_pid(pid) -> pid
        name -> Process.whereis(name)
      end

    case resolved do
      nil ->
        :ok

      sup ->
        sup
        |> DynamicSupervisor.which_children()
        |> Enum.each(fn
          {_id, child_pid, _type, _modules} when is_pid(child_pid) ->
            DynamicSupervisor.terminate_child(sup, child_pid)

          _not_a_pid ->
            :ok
        end)
    end
  end

  @spec registry() :: registry()
  defp registry do
    case :persistent_term.get(@pt_key, nil) do
      nil -> reload()
      registry -> registry
    end
  end

  @spec build([module()]) :: registry()
  defp build(modules) do
    entries =
      for module <- modules, placement <- module.spawn(), do: {module, placement}

    index =
      for {module, placement} <- entries,
          into: %{},
          do: {{placement.map, placement.x, placement.y}, {module, placement}}

    by_unit =
      for {module, placement} <- entries,
          into: %{},
          do: {entity_id(placement), {module, placement}}

    by_name =
      entries
      |> Enum.reject(fn {_module, placement} -> placement.unique_name == "" end)
      |> Enum.group_by(fn {_module, placement} -> placement.unique_name end)

    by_label =
      for {module, placement} <- entries,
          label <- module.events(),
          do: {label, {module, entity_id(placement)}}

    by_label =
      by_label
      |> Enum.group_by(fn {label, _entry} -> label end, fn {_label, entry} -> entry end)
      |> Map.new(fn {label, entries} -> {label, Enum.uniq(entries)} end)

    touch_rects =
      entries
      |> Enum.filter(fn {_module, placement} -> not is_nil(placement.trigger) end)
      |> Enum.group_by(
        fn {_module, placement} -> placement.map end,
        fn {_module, placement} -> touch_rect(placement) end
      )

    %{
      entries: entries,
      index: index,
      by_unit: by_unit,
      by_name: by_name,
      by_label: by_label,
      touch_rects: touch_rects
    }
  end

  @spec touch_rect(Placement.t()) :: touch_rect()
  defp touch_rect(%Placement{trigger: {xs, ys}} = placement) do
    {entity_id(placement), (placement.x - xs)..(placement.x + xs),
     (placement.y - ys)..(placement.y + ys)}
  end

  @spec default_app_modules() :: [module()]
  defp default_app_modules do
    case :application.get_key(:zone_server, :modules) do
      {:ok, modules} -> modules
      :undefined -> []
    end
  end

  @spec npc_modules([module()]) :: [module()]
  defp npc_modules(modules), do: Enum.filter(modules, &npc_module?/1)

  @spec npc_module?(module()) :: boolean()
  defp npc_module?(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> Npc in (module.module_info(:attributes)[:behaviour] || [])
      _ -> false
    end
  end
end
