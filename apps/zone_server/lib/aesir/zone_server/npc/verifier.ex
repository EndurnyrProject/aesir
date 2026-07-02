defmodule Aesir.ZoneServer.Npc.Verifier do
  @moduledoc """
  Boot/test sanity checks for registered NPC placements.

  Given the registry's `{module, placement}` entries:

    * `{:cell_collision, {map, x, y}, modules}` — two or more NPCs sharing one
      cell. NPC unit gids are derived deterministically from the cell, so
      colliding NPCs collapse onto one gid and only the registry's last-write
      survives on a click; the rest are shadowed and unreachable.

  A cell collision is a data problem worth surfacing, but it must **not** take
  the zone server down: one bad NPC (often an auto-imported duplicate) should
  never block boot. `verify!/1` therefore logs a warning per collision and boots
  on, leaving the surviving NPC reachable.

  NPCs are objects, not walking units, so a spawn cell is **not** required to be
  walkable — official NPCs routinely sit on walls, edges, and decorative cells.
  A placement on a map that is not loaded in `Aesir.ZoneServer.Map.MapCache` is
  likewise non-fatal: `verify!/1` logs a warning for it (likely a typo or a
  not-yet-imported map — the NPC is simply unreachable until that map is added).

  `verify/1` returns `:ok` or the list of detected collisions for programmatic
  use; `verify!/1` logs both the unloaded-map and collision warnings and always
  returns `:ok`.
  """

  require Logger

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement

  @type entry :: {module(), Placement.t()}
  @type cell :: {String.t(), non_neg_integer(), non_neg_integer()}
  @type error :: {:cell_collision, cell(), [module()]}

  @doc """
  Verifies the given placement entries, returning `:ok` or the list of fatal
  errors (cell collisions).
  """
  @spec verify([entry()]) :: :ok | {:error, [error()]}
  def verify(entries) do
    case collision_errors(entries) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Boot-time verification: logs a warning for every placement on a map that is not
  loaded and for every cell collision (mirroring
  `Aesir.ZoneServer.Npc.Warps.sanitize/1`'s non-fatal handling), then always
  returns `:ok`. Invalid NPCs are dropped/shadowed, never fatal to boot.
  """
  @spec verify!([entry()]) :: :ok
  def verify!(entries) do
    warn_unloaded_maps(entries)
    warn_collisions(entries)

    :ok
  end

  @spec warn_collisions([entry()]) :: :ok
  defp warn_collisions(entries) do
    for {:cell_collision, {map, x, y}, modules} <- collision_errors(entries) do
      Logger.warning(
        "NPC cell collision at #{inspect({map, x, y})}: #{inspect(modules)} share one cell; " <>
          "only one will be reachable, the rest are shadowed."
      )
    end

    :ok
  end

  @spec warn_unloaded_maps([entry()]) :: :ok
  defp warn_unloaded_maps(entries) do
    for {module, %Placement{map: map}} <- entries, not MapCache.exists?(map) do
      Logger.warning(
        "NPC #{inspect(module)} is placed on map #{inspect(map)}, which is not loaded; " <>
          "it will be unreachable until that map is added to the cache."
      )
    end

    :ok
  end

  @spec collision_errors([entry()]) :: [error()]
  defp collision_errors(entries) do
    entries
    |> Enum.group_by(fn {_module, p} -> {p.map, p.x, p.y} end, &elem(&1, 0))
    |> Enum.filter(fn {_cell, modules} -> length(modules) > 1 end)
    |> Enum.map(fn {cell, modules} -> {:cell_collision, cell, modules} end)
  end
end
