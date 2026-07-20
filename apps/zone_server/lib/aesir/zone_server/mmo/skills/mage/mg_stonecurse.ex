defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgStonecurse do
  @moduledoc """
  Stone Curse (MG_STONECURSE). No-damage earth petrification consuming a Red Gemstone.

  rAthena renewal: range 2, single target, no damage. Rolls `(4 * level + 20)`% to
  apply `sc_stone`, which enters its own wait -> petrify phases (timing encoded in the
  status effect). The Red Gemstone catalyst is consumed on success; for levels 6-10 a
  failed petrify keeps the gem (`SKILL_NOCONSUME_REQ`), modeled as `{:ok, caster,
  :no_consume}`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 16,
    name: :mg_stonecurse,
    display_name: "Stone Curse",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    element: :earth,
    range: 2,
    cast_time: List.duplicate(800, 10),
    fixed_cast_time: List.duplicate(200, 10),
    sp_cost: [25, 24, 23, 22, 21, 20, 19, 18, 17, 16],
    item_cost: [%{id: 716, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, _definition) do
    if :rand.uniform(100) <= success_chance(level) do
      unit_type = target_unit_type(target_id)

      StatusInterpreter.apply_status(unit_type, target_id, :sc_stone,
        val1: level,
        caster_id: caster_id
      )

      {:ok, caster}
    else
      fail_result(caster, level)
    end
  end

  @spec success_chance(pos_integer()) :: pos_integer()
  defp success_chance(level), do: 4 * level + 20

  @spec fail_result(PlayerState.t(), pos_integer()) ::
          {:ok, PlayerState.t()} | {:ok, PlayerState.t(), :no_consume}
  defp fail_result(caster, level) when level > 5, do: {:ok, caster, :no_consume}
  defp fail_result(caster, _level), do: {:ok, caster}

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
