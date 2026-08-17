defmodule Aesir.ZoneServer.Npc.Verifier do
  @moduledoc """
  Boot/test sanity checks for registered NPC placements.

  Given the registry's `{module, placement}` entries:

    * `{:cell_collision, {map, x, y}, modules}` — two or more NPCs sharing one
      cell **and** one `unique_name`. NPC unit gids are derived from
      `{map, x, y, unique_name}`, so stacked NPCs with distinct unique names each
      get their own gid and stay independently addressable (a visible guide plus
      an invisible `waitingroom` controller on the same cell is normal and fine).
      Only a shared cell *and* unique name collapses onto one gid, shadowing all
      but the registry's last write on a click — that is the real data problem.

  A cell collision is a data problem worth surfacing, but it must **not** take
  the zone server down: one bad NPC (often an auto-imported duplicate) should
  never block boot. `verify!/1` therefore logs a warning per collision and boots
  on, leaving the surviving NPC reachable.

  NPCs are objects, not walking units, so a spawn cell is **not** required to be
  walkable — official NPCs routinely sit on walls, edges, and decorative cells.

  `verify/1` returns `:ok` or the list of detected collisions for programmatic
  use; `verify!/1` logs the collision warnings and always returns `:ok`.
  """

  require Logger

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
  Boot-time verification: logs a warning for every cell collision (mirroring
  `Aesir.ZoneServer.Npc.Warps.sanitize/1`'s non-fatal handling), then always
  returns `:ok`. Invalid NPCs are dropped/shadowed, never fatal to boot.
  """
  @spec verify!([entry()]) :: :ok
  def verify!(entries) do
    warn_collisions(entries)

    :ok
  end

  @spec warn_collisions([entry()]) :: :ok
  defp warn_collisions(entries) do
    for {:cell_collision, {map, x, y}, modules} <- collision_errors(entries) do
      Logger.debug(
        "NPC cell collision at #{inspect({map, x, y})}: #{inspect(modules)} share a cell " <>
          "and unique_name; only one will be reachable, the rest are shadowed."
      )
    end

    :ok
  end

  @spec collision_errors([entry()]) :: [error()]
  defp collision_errors(entries) do
    entries
    |> Enum.group_by(
      fn {_module, p} -> {p.map, p.x, p.y, p.unique_name} end,
      &elem(&1, 0)
    )
    |> Enum.filter(fn {_key, modules} -> length(modules) > 1 end)
    |> Enum.map(fn {{map, x, y, _unique_name}, modules} ->
      {:cell_collision, {map, x, y}, modules}
    end)
  end
end
