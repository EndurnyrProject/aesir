defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Overlap do
  @moduledoc """
  Whether a performance cell is dissonant: another live song (or dance) field
  covers the same cell as this song (or dance). Ensembles and unrelated ground
  units never create dissonance. Checked live, so the overlap holds exactly as
  long as both fields cover the cell (rAthena `skill_dance_overlap`).
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @doc "Returns whether another live performance of the same kind covers the cell."
  @spec dissonant?(Group.t(), Group.cell()) :: boolean()
  def dissonant?(%Group{state: %{performance: %{kind: kind}}} = group, {x, y})
      when kind in [:song, :dance] do
    group.map_name
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.any?(fn other ->
      other.group_id != group.group_id and match?(%{performance: %{kind: ^kind}}, other.state)
    end)
  end

  def dissonant?(_group, _cell), do: false
end
