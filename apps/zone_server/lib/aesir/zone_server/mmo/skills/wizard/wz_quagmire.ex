defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire do
  @moduledoc """
  Quagmire (WZ_QUAGMIRE), a source-owned enemy ground field.

  Renewal data is from rAthena `db/re/skill_db.yml:3791-3850`: ID 92,
  `Layout: 2` (3x3), nine-cell range, 5–25 second duration, 5–25 SP, enemy
  targeting, and `ActiveInstance: 3` (`:3806`). The fourth cast removes the
  earliest-expiring field first. `src/map/skill.cpp:6512-6515` applies the status only to a
  valid enemy; `src/map/status.cpp:11443-11445` sets the AGI/DEX penalty to
  `5 * level` for players and `10 * level` for non-players. The database
  interval is `-1`; the 1,000 ms manager interval only reconciles source-owned
  support for stationary occupants and does not add a Renewal combat tick.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 92,
    name: :wz_quagmire,
    display_name: "Quagmire",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    range: 9,
    element: :earth,
    unit_duration: [5_000, 10_000, 15_000, 20_000, 25_000],
    duration: [5_000, 10_000, 15_000, 20_000, 25_000],
    sp_cost: [5, 10, 15, 20, 25],
    after_cast_delay: List.duplicate(1_000, 5),
    status: :sc_quagmire

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skill.Unit.LifecyclePolicy
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @reconcile_interval 1_000

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, 1),
       state: %{},
       interval: @reconcile_interval,
       initial_delay: 0,
       duration: Enum.at(definition.unit_duration, level - 1),
       lifecycle_policy: %LifecyclePolicy{max_instances_per_caster: 3}
     }}
  end

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  @spec field_support(Group.t()) :: map()
  def field_support(%Group{} = group) do
    %{
      status_type: :sc_quagmire,
      params: &params_for(group.level, &1, &2),
      target?: &enemy?(group, &1)
    }
  end

  @spec params_for(pos_integer(), atom(), integer()) :: keyword()
  defp params_for(level, :player, _unit_id), do: [level: level, val1: level, val2: 5 * level]
  defp params_for(level, _unit_type, _unit_id), do: [level: level, val1: level, val2: 10 * level]

  defp enemy?(%Group{} = group, {target_type, target_id}) do
    with {:ok, {_module, caster, _pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id),
         {:ok, {_module, target, _pid}} <- UnitRegistry.get_unit(target_type, target_id) do
      Targeting.validate_enemy(caster, target) == :ok
    else
      _ -> false
    end
  end
end
