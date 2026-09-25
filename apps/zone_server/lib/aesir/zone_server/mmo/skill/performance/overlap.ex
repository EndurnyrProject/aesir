defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Overlap do
  @moduledoc """
  Recomputes dissonant cells from the current live field groups.

  Two songs or two dances sharing a cell suppress their occupant buffs there;
  ensembles and unrelated ground units never create dissonance.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @doc "Marks the cells shared with another live performance of the same kind."
  @spec mark(Group.t()) :: Group.t()
  def mark(%Group{state: %{performance: %{kind: kind}}, cells: cells} = group)
      when kind in [:song, :dance] do
    marked =
      for {x, y} = cell <- cells,
          other <- Storage.get_groups_at_cell(group.map_name, x, y),
          other.group_id != group.group_id,
          match?(%{performance: %{kind: ^kind}}, other.state),
          into: MapSet.new(),
          do: cell

    put_in(group.state.performance.dissonant_cells, marked)
  end

  def mark(group), do: group

  @doc "Returns whether this group's latest overlap pass marked the cell."
  @spec dissonant?(Group.t(), Group.cell()) :: boolean()
  def dissonant?(%Group{state: %{performance: %{dissonant_cells: cells}}}, cell),
    do: MapSet.member?(cells, cell)

  def dissonant?(_group, _cell), do: false
end
