defmodule Aesir.ZoneServer.Mmo.Skills.Thief.TfSprinklesand do
  @moduledoc """
  Sand Attack (TF_SPRINKLESAND). Earth-element weapon strike that can blind.

  rAthena renewal: 130% weapon damage, earth element, no crit, range 1. On a
  connecting hit it rolls 20% to apply `sc_blind` for 18000 ms.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 149,
    name: :tf_sprinklesand,
    display_name: "Sand Attack",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    element: :earth,
    range: 1,
    sp_cost: [9],
    quest_skill: true,
    quest_owner_job: :thief

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @blind_chance 20

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 130,
      element: :earth,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        maybe_blind(target_id)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec maybe_blind(integer()) :: :ok
  defp maybe_blind(target_id) do
    if :rand.uniform(100) <= @blind_chance do
      unit_type = target_unit_type(target_id)
      StatusInterpreter.apply_status(unit_type, target_id, :sc_blind, duration: 18_000)
    end

    :ok
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
