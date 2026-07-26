defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfThrowstone do
  @moduledoc """
  Stone Fling (TF_THROWSTONE). Fixed-damage misc attack that can stun or blind.

  rAthena renewal: fixed 50 damage (player-cast), neutral element, range 7.
  Misc damage ignores flee and cannot miss, so the status rolls always
  evaluate: 3% stun for 4500 ms, and only when the stun does not apply, 3%
  blind for 18000 ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 152,
    name: :tf_throwstone,
    display_name: "Stone Fling",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :misc,
    element: :neutral,
    range: 7,
    sp_cost: [2],
    quest_skill: true,
    quest_owner_job: :thief

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @base_damage 50
  @stun_chance 3
  @blind_chance 3

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      base_damage: @base_damage,
      element: :neutral
    ]

    case Combat.execute_misc_attack(caster, target_id, opts) do
      :ok ->
        maybe_stun_or_blind(target_id)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec maybe_stun_or_blind(integer()) :: :ok
  defp maybe_stun_or_blind(target_id) do
    unit_type = target_unit_type(target_id)

    if :rand.uniform(100) <= @stun_chance do
      StatusInterpreter.apply_status(unit_type, target_id, :sc_stun, duration: 4_500)
    else
      maybe_blind(unit_type, target_id)
    end

    :ok
  end

  @spec maybe_blind(atom(), integer()) :: :ok
  defp maybe_blind(unit_type, target_id) do
    if :rand.uniform(100) <= @blind_chance do
      StatusInterpreter.apply_status(unit_type, target_id, :sc_blind, duration: 18_000)
    end

    :ok
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
