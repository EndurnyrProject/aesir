defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmBash do
  @moduledoc """
  Bash (SM_BASH). Single-target physical strike on an enemy.

  rAthena: base 100% + 30% per level weapon damage, weapon element, no crit.
  On a confirmed hit it applies any skill riders contributed by learned passives
  (notably SM_FATALBLOW's stun above level 5) to the target.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 5,
    name: :sm_bash,
    display_name: "Bash",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    sp_cost: [8, 8, 8, 8, 8, 15, 15, 15, 15, 15]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Passives
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 30 * level,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: true}} ->
        apply_riders(caster, target, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp apply_riders(%{character_id: _} = caster, target, level) do
    :sm_bash
    |> Passives.rider_for(level, caster)
    |> Enum.each(fn {:apply_status, status_id, opts} ->
      maybe_apply_rider(caster, target, status_id, opts)
    end)
  end

  defp apply_riders(_caster, _target, _level), do: :ok

  defp maybe_apply_rider(%{character_id: caster_id}, target, status_id, opts) do
    chance = Keyword.fetch!(opts, :chance)

    if :rand.uniform(10_000) <= chance do
      {unit_type, unit_id} = target_ref(target)

      StatusInterpreter.apply_status(unit_type, unit_id, status_id,
        duration: opts[:duration],
        caster_id: caster_id,
        source_type: :player
      )
    end

    :ok
  end

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
