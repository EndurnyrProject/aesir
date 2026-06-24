defmodule Aesir.ZoneServer.Npc.Verifier do
  @moduledoc """
  Boot/test sanity checks for registered NPC placements.

  Given the registry's `{module, placement}` entries, returns errors for:

    * `{:non_walkable, module, {map, x, y}}` — a spawn cell that is not walkable
      (checked via `Aesir.ZoneServer.Map.MapCache.walkable?/3`, the same API the
      warp importer uses);
    * `{:cell_collision, {map, x, y}, modules}` — two or more NPCs on one cell.

  Returns `:ok` when there are no errors.
  """

  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Npc.Placement

  @type entry :: {module(), Placement.t()}
  @type cell :: {String.t(), non_neg_integer(), non_neg_integer()}
  @type error ::
          {:non_walkable, module(), cell()}
          | {:cell_collision, cell(), [module()]}

  @doc """
  Verifies the given placement entries, returning `:ok` or the list of errors.
  """
  @spec verify([entry()]) :: :ok | {:error, [error()]}
  def verify(entries) do
    case walkable_errors(entries) ++ collision_errors(entries) do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @spec walkable_errors([entry()]) :: [error()]
  defp walkable_errors(entries) do
    for {module, %Placement{map: map, x: x, y: y}} <- entries,
        not MapCache.walkable?(map, x, y),
        do: {:non_walkable, module, {map, x, y}}
  end

  @spec collision_errors([entry()]) :: [error()]
  defp collision_errors(entries) do
    entries
    |> Enum.group_by(fn {_module, p} -> {p.map, p.x, p.y} end, &elem(&1, 0))
    |> Enum.filter(fn {_cell, modules} -> length(modules) > 1 end)
    |> Enum.map(fn {cell, modules} -> {:cell_collision, cell, modules} end)
  end
end
