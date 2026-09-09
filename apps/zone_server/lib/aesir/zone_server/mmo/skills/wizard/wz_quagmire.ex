defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzQuagmire do
  @moduledoc """
  Quagmire (WZ_QUAGMIRE). A 3x3 enemy ground field with a 9-cell range, 5 to 25 s
  duration, 5 to 25 SP, and at most three fields per caster (the fourth cast removes
  the oldest).

  Occupants lose 5 AGI and DEX per level (10 per level for non-players) and move at
  half speed. The 1 s manager interval only reconciles support for stationary
  occupants and adds no combat tick. Renewal and pre-renewal agree.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 92,
    name: :wz_quagmire,
    requires: [],
    display_name: "Quagmire",
    max_level: 5,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
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
    with {:ok, {_caster_module, caster, _caster_pid}} <-
           UnitRegistry.get_unit(group.caster_type, group.caster_id),
         {:ok, {_target_module, target, _target_pid}} <-
           UnitRegistry.get_unit(target_type, target_id) do
      field_target?(group, caster, target)
    else
      _unavailable -> false
    end
  end

  defp field_target?(%Group{caster_type: :player} = group, caster, target),
    do: Targeting.validate_field_target(group, caster, target) == :ok

  defp field_target?(%Group{caster_type: :mob}, caster, target),
    do: Targeting.validate_enemy(caster, target) == :ok

  defp field_target?(%Group{}, _caster, _target), do: false
end
