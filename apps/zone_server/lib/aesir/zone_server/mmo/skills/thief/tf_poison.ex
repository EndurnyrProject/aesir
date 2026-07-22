defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfPoison do
  @moduledoc """
  Envenom (TF_POISON). Weapon strike that adds flat mastery ATK and can poison.

  rAthena renewal: 100% weapon damage + `15 * level` flat ATK, poison element,
  no crit, weapon range. On a connecting hit it rolls `4 * level + 10`% to apply
  `sc_poison` for 18000 ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 52,
    name: :tf_poison,
    display_name: "Envenom",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    element: :poison,
    range: -1,
    sp_cost: List.duplicate(12, 10)

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
      skill_ratio: 100,
      bonus_atk: 15 * level,
      element: :poison,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        maybe_poison(target_id, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec maybe_poison(integer(), pos_integer()) :: :ok
  defp maybe_poison(target_id, level) do
    if :rand.uniform(100) <= 4 * level + 10 do
      unit_type = target_unit_type(target_id)
      StatusInterpreter.apply_status(unit_type, target_id, :sc_poison, duration: 18_000)
    end

    :ok
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
