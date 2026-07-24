defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycross do
  @moduledoc """
  Holy Cross (CR_HOLYCROSS). Two-hit melee weapon strike in holy element with
  a chance to blind the target.

  Skill ratio is 35% per level, doubled to 70% per level when the caster
  wields a two-handed spear; mob casters have no equipment to check and always
  use the base ratio. Two hits, no crit. On a connecting hit, 3% per level
  chance to inflict Blind for 18 seconds.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 253,
    name: :cr_holycross,
    display_name: "Holy Cross",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    element: :holy,
    range: -1,
    hit_count: 2,
    sp_cost: [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @blind_duration 18_000

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster, level),
      hit_count: definition.hit_count,
      element: definition.element,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: hit?}} ->
        if hit?, do: maybe_blind(target_id, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  @spec skill_ratio(struct() | map(), pos_integer()) :: pos_integer()
  defp skill_ratio(%PlayerState{stats: %{equipment: equipment}}, level) do
    if Stats.weapon_type(equipment) == :two_handed_spear do
      70 * level
    else
      35 * level
    end
  end

  defp skill_ratio(_caster, level), do: 35 * level

  @spec maybe_blind(integer(), pos_integer()) :: :ok
  defp maybe_blind(target_id, level) do
    if :rand.uniform(100) <= 3 * level do
      unit_type = target_unit_type(target_id)
      StatusInterpreter.apply_status(unit_type, target_id, :sc_blind, duration: @blind_duration)
    end

    :ok
  end

  @spec target_unit_type(integer()) :: :mob | :player
  defp target_unit_type(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id), do: :mob, else: :player
  end
end
