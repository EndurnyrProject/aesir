defmodule Aesir.ZoneServer.Mmo.Skills.Shared.CellStatus do
  @moduledoc """
  The status a ground unit grants to whoever stands on its cells (Safety Wall,
  Pneuma).

  The grant happens only when a unit comes onto a cell: when the field is
  placed over it or when it steps in. A unit already holding the status is left
  alone, and a hidden unit does not acquire it (unless the skill reaches hidden
  units), even if it unhides later while standing still. The field's `on_out`
  removes the status when a unit steps off or the cell it stands on is deleted.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Grants `status` with `params` to `unit` as it comes onto one of the group's cells."
  @spec grant(Group.t(), Definition.t(), atom(), keyword(), Ref.t()) :: :ok
  def grant(%Group{} = group, definition, status, params, {unit_type, unit_id} = unit) do
    if CombatTarget.combat_unit?(unit) and living?(unit) and
         not StatusStorage.has_status?(unit_type, unit_id, status) and
         Targeting.placement_reaches?(definition, unit) do
      StatusInterpreter.apply_status(
        unit_type,
        unit_id,
        status,
        Keyword.merge([caster_id: group.caster_id, source_type: group.caster_type], params)
      )
    end

    :ok
  end

  @doc "Grants `status` to every unit standing on the group's cells when it is placed."
  @spec grant_occupants(Group.t(), Definition.t(), atom(), keyword()) :: :ok
  def grant_occupants(%Group{} = group, definition, status, params) do
    group
    |> occupants()
    |> Enum.each(&grant(group, definition, status, params, &1))
  end

  defp occupants(%Group{map_name: map_name, cells: cells}) do
    cells
    |> Enum.flat_map(fn {x, y} -> SpatialIndex.get_all_units_in_range(map_name, x, y, 0) end)
    |> Enum.uniq()
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      {:error, :not_found} -> false
    end
  end
end
