defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgGraffiti do
  @moduledoc """
  Scribble (RG_GRAFFITI), a map-wide persistent ground marker.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 220,
    name: :rg_graffiti,
    requires: [:inventory],
    display_name: "Scribble",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    range: 1,
    unit_duration: [180_000],
    sp_cost: [15],
    item_cost: [%{id: 716, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage

  @behaviour Ground

  def validate(%{map_name: map_name}, {:ground, _x, _y}, _level, _definition) do
    if Enum.any?(Storage.all(), &(&1.map_name == map_name and &1.skill_name == :rg_graffiti)) do
      {:error, :graffiti_already_placed}
    else
      :ok
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center}) do
    {:ok, %{cells: [center], state: %{}, interval: 1_000, duration: 180_000}}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}
end
