defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtDetecting do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 130,
    name: :ht_detecting,
    display_name: "Detecting",
    max_level: 4,
    target_type: :ground,
    damage_type: :no_damage,
    range: [3, 5, 7, 9],
    splash_radius: 3,
    sp_cost: [8, 8, 8, 8]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Unit.CombatTarget
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Handlers.FalconHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @hidden_statuses [:sc_hiding, :sc_cloaking]

  @impl Active
  def validate(%PlayerState{} = caster, {:ground, _x, _y}, _level, _definition) do
    if FalconHandler.falcon?(caster), do: :ok, else: {:error, :falcon_required}
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :falcon_required}

  @impl Active
  def cast(%PlayerState{map_name: map_name} = caster, {:ground, x, y}, _level, definition) do
    with {:ok, _group_ids} <- Manager.reveal_traps(map_name, x, y, definition.splash_radius) do
      map_name
      |> SpatialIndex.get_all_units_in_range(x, y, definition.splash_radius * 2)
      |> Enum.filter(fn target ->
        CombatTarget.combat_unit?(target) and
          inside_square?(target, map_name, x, y, definition.splash_radius) and living?(target)
      end)
      |> Enum.each(&Helpers.remove_statuses(&1, @hidden_statuses))

      {:ok, caster}
    end
  end

  defp inside_square?({unit_type, unit_id}, map_name, center_x, center_y, radius) do
    case SpatialIndex.get_unit_position(unit_type, unit_id) do
      {:ok, {x, y, ^map_name}} -> abs(x - center_x) <= radius and abs(y - center_y) <= radius
      {:ok, {_x, _y, _other_map}} -> false
      {:error, :not_found} -> false
    end
  end

  defp living?({unit_type, unit_id}) do
    case UnitRegistry.get_unit(unit_type, unit_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      {:error, :not_found} -> false
    end
  end
end
