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
  """

  alias Aesir.ZoneServer.Npc
  alias Aesir.ZoneServer.Npc.Placement

  @pt_key __MODULE__

  # Reserved high gid range for static NPC entities, disjoint from every other
  # gid: mob `instance_id`s (2..1_999_999), player `character_id`s (low DB PKs),
  # floor item ids (hex *strings*, never integers), and warp entities
  # (`0x4000_0000` base, see `Npc.Warp.Registry`). `:erlang.phash2/1` yields
  # 0..2^27-1, so NPC gids span `0x5000_0000..0x57FF_FFFF`, within `uint32`
  # (the `UnitSpawn.gid` width). Two cells hashing to the same gid is the same
  # collision risk warps accept; the `Verifier` cell-collision check is separate.
  @npc_entity_id_base 0x5000_0000

  @typedoc "A discovered NPC module paired with one of its placements."
  @type entry :: {module(), Placement.t()}

  @typedoc "Maps a spawn cell to the NPC module that owns it and its placement."
  @type index :: %{{String.t(), non_neg_integer(), non_neg_integer()} => entry()}

  @typedoc "Maps a placement's synthetic unit id to the NPC module that owns it."
  @type by_unit :: %{non_neg_integer() => entry()}

  @typedoc "The stored registry: the raw entries plus the cell and unit indexes."
  @type registry :: %{entries: [entry()], index: index(), by_unit: by_unit()}

  @doc """
  Rebuilds the registry from the given modules (default: the `:zone_server`
  application's modules), keeping only those declaring the `Npc` behaviour.

  Stores the fresh registry in `:persistent_term`, replacing any previous one,
  and returns it. The `modules` argument is an injectable seam for tests, which
  pass their own in-file NPC modules.
  """
  @spec reload([module()]) :: registry()
  def reload(modules \\ default_app_modules()) do
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

  A pure function of `{map, x, y}` in the reserved NPC range, mirroring
  `Npc.Warp.Registry.entity_id/1`: the same placement always resolves to the
  same gid across runs and nodes, with no process or registry write.
  """
  @spec entity_id(Placement.t()) :: non_neg_integer()
  def entity_id(%Placement{} = placement) do
    @npc_entity_id_base + :erlang.phash2({placement.map, placement.x, placement.y})
  end

  @doc """
  Resolves a spawned NPC's unit id back to its module and placement.

  This is the click-routing seam: a client `NpcTalk` carries the unit id of the
  NPC it clicked, and the session resolves it through here to the NPC module.
  """
  @spec module_for_unit(non_neg_integer()) :: {:ok, entry()} | :error
  def module_for_unit(unit_id), do: Map.fetch(registry().by_unit, unit_id)

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

    %{entries: entries, index: index, by_unit: by_unit}
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
