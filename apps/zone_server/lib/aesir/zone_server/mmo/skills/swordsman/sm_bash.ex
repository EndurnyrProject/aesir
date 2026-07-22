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
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 30 * level,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        apply_riders(caster, target_id, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec apply_riders(struct(), integer(), pos_integer()) :: :ok
  defp apply_riders(caster, target_id, level) do
    :sm_bash
    |> Passives.rider_for(level, caster)
    |> Enum.each(fn {:apply_status, status_id, opts} ->
      maybe_apply_rider(target_id, status_id, opts)
    end)
  end

  @spec maybe_apply_rider(integer(), atom(), keyword()) :: :ok
  defp maybe_apply_rider(target_id, status_id, opts) do
    chance = Keyword.fetch!(opts, :chance)

    if :rand.uniform(10_000) <= chance do
      unit_type = target_unit_type(target_id)
      StatusInterpreter.apply_status(unit_type, target_id, status_id, duration: opts[:duration])
    end

    :ok
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
