defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgFlaggraffiti do
  @moduledoc """
  Piece (RG_FLAGGRAFFITI), a persistent ground marker.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 221,
    name: :rg_flaggraffiti,
    requires: [:player_state],
    display_name: "Piece",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    unit_duration: [180_000, 180_000, 180_000, 180_000, 180_000],
    sp_cost: [10, 10, 10, 10, 10]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center}) do
    {:ok, %{cells: [center], state: %{}, interval: 1_000, duration: 180_000}}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}
end
