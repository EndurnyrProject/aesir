defmodule Aesir.ZoneServer.Npc.Verifier do
  @moduledoc """
  Boot/test sanity checks for registered NPC placements.

  Given the registry's `{module, placement}` entries:

    * `{:cell_collision, {map, x, y}, modules}` — two or more NPCs sharing one
      cell — is a **fatal** error. NPC unit gids are derived deterministically
      from the cell, so colliding NPCs would collapse onto one gid and shadow
      each other on a click.

  NPCs are objects, not walking units, so a spawn cell is **not** required to be
  walkable — official NPCs routinely sit on walls, edges, and decorative cells.
  A placement on a map that is not loaded in `Aesir.ZoneServer.Map.MapCache` is
  likewise not fatal: `verify!/1` logs a warning for it (likely a typo or a
  not-yet-imported map — the NPC is simply unreachable until that map is added)
  and boots on.

  `verify/1` returns `:ok` or the list of fatal errors; `verify!/1` logs the
  unloaded-map warnings and then raises on any fatal error.
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
  loaded (mirroring `Aesir.ZoneServer.Npc.Warps.sanitize/1`'s non-fatal handling),
  then returns `:ok` or raises `ArgumentError` on a fatal error (a cell collision).
  """
  @spec verify!([entry()]) :: :ok
  def verify!(entries) do
    warn_unloaded_maps(entries)

    case verify(entries) do
      :ok -> :ok
      {:error, errors} -> raise ArgumentError, "invalid NPC placements: #{inspect(errors)}"
    end
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
