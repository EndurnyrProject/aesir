defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgStonecurse do
  @moduledoc """
  Stone Curse (MG_STONECURSE). No-damage earth petrification consuming a Red Gemstone.

  A near-melee single-target curse that rolls `4 * level + 20` percent to apply
  the petrification status. The skill's declared duration is the status' whole
  life: the target spends the first five seconds in the wait phase and the rest
  petrified. The Red Gemstone catalyst is consumed on success; from level 6 up a
  failed roll keeps the gem.

  Renewal: the status runs 17 seconds, so five seconds of wait and twelve of
  stone, and the cast is 0.8 seconds of variable time plus a 0.2 second fixed
  component.

  Pre-renewal: the status runs 20 seconds, so five seconds of wait and fifteen of
  stone, and the cast is a flat 1 second of purely variable time with no fixed
  component, so DEX shortens all of it.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 16,
    name: :mg_stonecurse,
    requires: [:inventory],
    display_name: "Stone Curse",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :earth,
    range: 2,
    cast_time: [renewal: List.duplicate(800, 10), pre_renewal: List.duplicate(1000, 10)],
    fixed_cast_time: List.duplicate(200, 10),
    duration: [
      renewal: List.duplicate(17_000, 10),
      pre_renewal: List.duplicate(20_000, 10)
    ],
    sp_cost: [25, 24, 23, 22, 21, 20, 19, 18, 17, 16],
    item_cost: [%{id: 716, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    if :rand.uniform(100) <= success_chance(level) do
      unit_type = target_unit_type(target_id)

      StatusInterpreter.apply_status(unit_type, target_id, :sc_stone,
        val1: level,
        caster_id: caster_id,
        duration: Enum.at(definition.duration, level - 1)
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
