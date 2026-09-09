defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrHolycross do
  @moduledoc """
  Holy Cross (CR_HOLYCROSS). A two-hit holy weapon strike at 2 cells for 11 to 20
  SP, 100% plus 35% per level per hit with no criticals, blinding 3% per level of
  the time on a connecting hit.

  Renewal raises the per-level part to 70% with a two-handed spear and blinds for
  18 s; pre-renewal keeps 35% per level with every weapon and blinds for 30 s.
  Mob casters always use the base ratio.
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
    range: 2,
    hit_count: 2,
    sp_cost: [11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
    duration: [renewal: List.duplicate(18_000, 10), pre_renewal: List.duplicate(30_000, 10)]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster, level),
      hit_count: definition.hit_count,
      element: definition.element,
      skip_crit: true,
      report_hit: true,
      skip_range: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: hit?}} ->
        if hit?, do: maybe_blind(caster, target, level, Enum.at(definition.duration, level - 1))
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  # Renewal raises the per-level part for a two-handed spear; classic and mob casters use the base.
  @spec skill_ratio(struct() | map(), pos_integer()) :: pos_integer()
  defp skill_ratio(%PlayerState{stats: %{equipment: equipment}}, level) do
    if GameMode.mode() == :renewal and Stats.weapon_type(equipment) == :two_handed_spear,
      do: 100 + 70 * level,
      else: 100 + 35 * level
  end

  defp skill_ratio(_caster, level), do: 100 + 35 * level

  defp maybe_blind(caster, target, level, duration) do
    if :rand.uniform(100) <= 3 * level do
      {unit_type, unit_id} = target_ref(target)
      {source_type, source_id} = source_ref(caster)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_blind,
        duration: duration,
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
