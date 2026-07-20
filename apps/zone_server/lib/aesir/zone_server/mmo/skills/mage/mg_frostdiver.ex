defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgFrostdiver do
  @moduledoc """
  Frost Diver (MG_FROSTDIVER). Single-target water magic that can freeze the target.

  rAthena renewal: water element, `(100 + 10 * level)`% MATK in a single hit, range 9.
  On a connecting hit it rolls `min(3 * level + 35, level + 60)`% to apply `sc_freeze`
  for `3000 * level` ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 15,
    name: :mg_frostdiver,
    display_name: "Frost Diver",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :water,
    range: 9,
    cast_time: List.duplicate(640, 10),
    fixed_cast_time: List.duplicate(160, 10),
    after_cast_delay: List.duplicate(500, 10),
    sp_cost: [25, 24, 23, 22, 21, 20, 19, 18, 17, 16]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 10 * level,
      hit_count: 1,
      element: definition.element,
      skip_range: true
    ]

    case Combat.execute_magic_attack(caster, target_id, opts) do
      :ok ->
        maybe_freeze(target_id, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec maybe_freeze(integer(), pos_integer()) :: :ok
  defp maybe_freeze(target_id, level) do
    if :rand.uniform(100) <= freeze_chance(level) do
      unit_type = target_unit_type(target_id)
      StatusInterpreter.apply_status(unit_type, target_id, :sc_freeze, duration: 3000 * level)
    end

    :ok
  end

  @spec freeze_chance(pos_integer()) :: pos_integer()
  defp freeze_chance(level), do: min(3 * level + 35, level + 60)

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
