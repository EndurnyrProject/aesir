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
    requires: [],
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
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster, level),
      hit_count: definition.hit_count,
      element: definition.element,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: hit?}} ->
        if hit?, do: maybe_blind(caster, target, level)
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

  defp maybe_blind(caster, target, level) do
    if :rand.uniform(100) <= 3 * level do
      {unit_type, unit_id} = target_ref(target)
      {source_type, source_id} = source_ref(caster)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_blind,
        duration: @blind_duration,
        caster_id: source_id,
        source_type: source_type
      )
    end

    :ok
  end

  defp source_ref(%{character_id: unit_id}), do: {:player, unit_id}
  defp source_ref(%{instance_id: unit_id}), do: {:mob, unit_id}
  defp source_ref(%{world_gid: unit_id}), do: {:homunculus, unit_id}

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
