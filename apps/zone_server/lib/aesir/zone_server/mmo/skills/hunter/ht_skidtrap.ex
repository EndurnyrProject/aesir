defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSkidtrap do
  @moduledoc """
  Skid Trap (HT_SKIDTRAP).

  A hidden contact trap that pushes an eligible enemy away from its caster's
  placement origin and applies Stop. The manager turns a successful `:expire`
  result into the shared visible used lifecycle.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 115,
    name: :ht_skidtrap,
    display_name: "Skid Trap",
    max_level: 5,
    target_type: :ground,
    range: 3,
    hit_interval: 1_000,
    unit_duration: [300_000, 240_000, 180_000, 120_000, 60_000],
    sp_cost: [10, 10, 10, 10, 10],
    item_cost: [%{id: 1065, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skills.Hunter.Trap
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Ground

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(
        %Group{center: center, level: level, caster_type: caster_type, caster_id: caster_id} =
          group
      ) do
    {:ok, %{stats: stats}} = UnitRegistry.get_unit_info(caster_type, caster_id)
    definition = definition()

    {:ok,
     %{
       cells: [center],
       state: Trap.place_state(level, stats, group),
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
  def on_touch(%Group{} = group, {unit_type, unit_id} = mover) do
    with true <- Trap.enemy?(group, mover),
         {:ok, {module, target, _pid}} <- UnitRegistry.get_unit(unit_type, unit_id),
         false <- module.is_boss?(target),
         false <- status_immune?(target),
         :ok <-
           StatusInterpreter.apply_status(unit_type, unit_id, :sc_stop,
             duration: 3_000,
             bypass_resistance: true,
             caster_id: group.caster_id,
             source_type: group.caster_type
           ) do
      {from_x, from_y} = knockback_origin(group)
      Knockback.knockback(unit_type, unit_id, from_x, from_y, group.level + 5)
      :expire
    else
      _ -> {:ok, group}
    end
  end

  defp knockback_origin(%Group{origin: {x, y} = origin, center: center}) when origin != center,
    do: {x, y}

  # An origin one cell west encodes a deterministic eastward push when caster and trap overlap.
  defp knockback_origin(%Group{center: {x, y}}), do: {x - 1, y}

  defp status_immune?(%MobState{mob_data: %MobDefinition{modes: modes}}),
    do: :status_immune in modes

  defp status_immune?(_target), do: false
end
