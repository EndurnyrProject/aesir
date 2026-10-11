defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgStonecurse do
  @moduledoc """
  Stone Curse (MG_STONECURSE). No-damage earth petrification consuming a Red Gemstone.

  A near-melee single-target curse that starts the petrifying wait (`sc_stonewait`)
  with a `4 * level + 20` percent chance, reduced by the target's status resistance in
  the same roll. The target waits five seconds, the skill's first duration, and the
  rest of its second duration petrified. Cast on a target that is already petrifying
  or petrified, it cures the petrification instead, which counts as a success.

  The Red Gemstone is consumed on success. It is also consumed against monsters immune
  to statuses and targets immune to magic, which fail before any roll; any other
  failure keeps it from level 6 up.

  Renewal: the status runs 17 seconds, five of them waiting, and the cast is 0.8
  seconds of variable time plus a 0.2 second fixed component.

  Pre-renewal: the status runs 20 seconds, five of them waiting, and the cast is a
  flat 1 second of purely variable time with no fixed component, so DEX shortens all
  of it.
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

  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @wait_ms 5_000

  @impl Active
  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    unit_type = target_unit_type(target_id)

    if status_immune?(unit_type, target_id) or MagicDefense.immune?({unit_type, target_id}) do
      {:ok, caster}
    else
      unit_type
      |> StatusInterpreter.apply_status(target_id, :sc_stonewait,
        val1: level,
        val2: caster_id,
        caster_id: caster_id,
        duration: Enum.at(definition.duration, level - 1),
        state: %{delay: @wait_ms},
        success_rate: 4 * level + 20
      )
      |> cast_result(caster, level)
    end
  end

  @spec cast_result(:ok | {:error, atom()}, PlayerState.t(), pos_integer()) ::
          {:ok, PlayerState.t()} | {:ok, PlayerState.t(), :no_consume}
  defp cast_result(:ok, caster, _level), do: {:ok, caster}
  defp cast_result({:error, :magic_immune}, caster, _level), do: {:ok, caster}

  defp cast_result({:error, _reason}, caster, level) when level > 5,
    do: {:ok, caster, :no_consume}

  defp cast_result({:error, _reason}, caster, _level), do: {:ok, caster}

  defp status_immune?(:mob, target_id) do
    case UnitRegistry.get_unit(:mob, target_id) do
      {:ok, {_module, %MobState{mob_data: %{modes: modes}}, _pid}} -> :status_immune in modes
      _other -> false
    end
  end

  defp status_immune?(_unit_type, _target_id), do: false

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
