defmodule Aesir.ZoneServer.Mmo.MobSkill.Archetype.GroundField do
  @moduledoc """
  Places a player ground skill's own field from a mob cast (`SA_LANDPROTECTOR`).

  Unlike `Archetype.GroundNuke`, which models a mob-only AoE and therefore
  builds and ticks its own group, a field skill already exists as a
  `Skill.Ground` module. This archetype reuses it: it builds the `Group` with
  `caster_type: :mob` and hands it to `Skill.Unit.place_group/2`, so `on_place/1`,
  the path check, `Manager` registration (including Land Protector suppression)
  and the cast broadcast are the exact same path a player cast takes. The group
  keeps the real `skill_name`, so `handler` stays `nil` and the manager resolves
  ticks/triggers from the player catalog as usual — no mob-specific dispatch.

  The catalog names the skill (`%{skill_name: :sa_landprotector}`); the row's
  `level` sizes the field through the skill module's own layout table.

  Ground placement is resolved from whatever the Executor handed over: rAthena
  casts a `CAST_GROUND` skill at the cell of the row's target, so a `:target`
  row (`{:unit, ...}`) places the field on that unit's cell and a `:self` row
  on the caster's own.
  """

  @behaviour Aesir.ZoneServer.Mmo.MobSkill.Archetype

  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  @spec apply(MobState.t(), Executor.target(), map(), pos_integer()) :: :ok | {:error, term()}
  def apply(%MobState{} = caster, target, params, level) do
    with {:ok, center} <- center(caster, target),
         {:ok, %Group{}} <-
           Unit.place_group(build_group(caster, params, level, center), origin(caster)) do
      :ok
    end
  end

  @spec center(MobState.t(), Executor.target()) ::
          {:ok, Group.cell()} | {:error, :no_target | :invalid_target}
  defp center(%MobState{}, {:ground, x, y, _area}), do: {:ok, {x, y}}

  defp center(%MobState{instance_id: instance_id} = caster, {:unit, :mob, instance_id}),
    do: {:ok, origin(caster)}

  defp center(%MobState{}, {:unit, unit_type, unit_id}) do
    if living_unit?(unit_type, unit_id) do
      case SpatialIndex.get_unit_position(unit_type, unit_id) do
        {:ok, {x, y, _map}} -> {:ok, {x, y}}
        {:error, :not_found} -> {:error, :no_target}
      end
    else
      {:error, :no_target}
    end
  end

  defp center(%MobState{}, _target), do: {:error, :invalid_target}

  defp living_unit?(unit_type, unit_id) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> TargetState.living?(state)
      _ -> false
    end
  end

  @spec build_group(MobState.t(), map(), pos_integer(), Group.cell()) :: Group.t()
  defp build_group(%MobState{} = caster, params, level, center) do
    %Group{
      group_id: System.unique_integer([:monotonic, :positive]),
      skill_id: params.skill_id,
      skill_name: params.skill_name,
      level: level,
      caster_id: caster.instance_id,
      caster_type: :mob,
      map_name: caster.map_name,
      center: center
    }
  end

  @spec origin(MobState.t()) :: Group.cell()
  defp origin(%MobState{x: x, y: y}), do: {x, y}
end
