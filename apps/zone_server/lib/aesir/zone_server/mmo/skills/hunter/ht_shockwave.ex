defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtShockwave do
  @moduledoc """
  Shockwave Trap (HT_SHOCKWAVE), a trap that drains SP.

  Renewal and pre-renewal agree: drains 5% plus 15% per level of the SP of the
  first enemy within one cell, lasting 200 s down to 40 s by level, for 45 SP
  and two traps. A monster loses no SP to it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 118,
    name: :ht_shockwave,
    no_reiteration: true,
    no_footset: true,
    unit_range: 1,
    is_trap: true,
    requires: [],
    display_name: "Shockwave Trap",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :misc,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [200_000, 160_000, 120_000, 80_000, 40_000],
    sp_cost: [45, 45, 45, 45, 45],
    item_cost: [%{id: 1065, amount: 2}],
    damage_splash: true

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
       unit_range: 1,
       visibility: Trap.visibility(:ht_shockwave)
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec unit_targets(Group.t(), Ground.cell(), [{atom(), integer()}]) :: [{atom(), integer()}]
  def unit_targets(%Group{} = group, _cell, refs), do: Trap.unit_targets(group, refs)

  @impl Ground
  @spec on_unit_hit(Group.t(), Ground.cell(), {atom(), integer()}, integer()) :: {:ok, Group.t()}
  def on_unit_hit(%Group{} = group, _cell, target, now) do
    with true <- Trap.armed?(group),
         {:ok, _caster} <- Trap.resolve_caster(group) do
      Resource.drain_sp_percent(target, percentage(group.level))
      {:ok, Trap.spring(group, now)}
    else
      _inert -> {:ok, group}
    end
  end

  defp percentage(level), do: Enum.at([20, 35, 50, 65, 80], level - 1)
end
