defmodule Aesir.ZoneServer.Unit.StaticEntity do
  @moduledoc """
  Shared visibility diffing for static (non-spatial-indexed) entities such as
  warps and NPCs. These placements are held per-map in registries and diffed
  against a `visible_*` MapSet by Manhattan distance at the call site; this
  helper owns the common spawn/vanish/diff step.
  """

  @doc """
  Diffs the in-range entities (keyed by their synthetic entity id) against the
  previously visible set, invoking `spawn_fun` with the entity for each
  newly-visible id and `vanish_fun` with the id for each newly-hidden id.

  Returns the new visible MapSet.
  """
  @spec diff_visibility(%{optional(id) => entity}, MapSet.t(), (entity -> any), (id -> any)) ::
          MapSet.t()
        when id: term(), entity: term()
  def diff_visibility(entities_by_id, old_visible, spawn_fun, vanish_fun) do
    new_visible = MapSet.new(Map.keys(entities_by_id))

    new_visible
    |> MapSet.difference(old_visible)
    |> Enum.each(fn id -> spawn_fun.(Map.fetch!(entities_by_id, id)) end)

    old_visible
    |> MapSet.difference(new_visible)
    |> Enum.each(fn id -> vanish_fun.(id) end)

    new_visible
  end
end
