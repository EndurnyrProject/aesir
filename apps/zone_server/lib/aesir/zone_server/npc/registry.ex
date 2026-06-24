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
  """

  alias Aesir.ZoneServer.Npc
  alias Aesir.ZoneServer.Npc.Placement

  @pt_key __MODULE__

  @typedoc "A discovered NPC module paired with one of its placements."
  @type entry :: {module(), Placement.t()}

  @typedoc "Maps a spawn cell to the NPC module that owns it and its placement."
  @type index :: %{{String.t(), non_neg_integer(), non_neg_integer()} => entry()}

  @typedoc "The stored registry: the raw entries and the collapsed lookup index."
  @type registry :: %{entries: [entry()], index: index()}

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

    %{entries: entries, index: index}
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
