defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave do
  @moduledoc """
  Shockwave Trap (HT_SHOCKWAVE), a hidden contact trap that drains maximum SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 118,
    name: :ht_shockwave,
    display_name: "Shockwave Trap",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :misc,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [200_000, 160_000, 120_000, 80_000, 40_000],
    sp_cost: [45, 45, 45, 45, 45],
    item_cost: [%{id: 1065, amount: 2}]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Unit.Resource

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level} = group) do
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, %{dex: 0, int: 0, base_level: 0}, group),
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1),
       visibility: :party_only
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec on_touch(Group.t(), {atom(), integer()}) :: {:ok, Group.t()} | :expire
  def on_touch(%Group{} = group, mover) do
    if Trap.enemy?(group, mover) do
      Resource.drain_sp_percent(mover, percentage(group.level))
      :expire
    else
      {:ok, group}
    end
  end

  defp percentage(level), do: Enum.at([20, 35, 50, 65, 80], level - 1)
end
