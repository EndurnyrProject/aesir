defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge do
  @moduledoc """
  Shield Charge (CR_SHIELDCHARGE). A single-hit melee shield bash: ratio
  100 + 20% per level of the shield damage base, with a chance to stun and
  knock the target back.

  A player caster must have a shield equipped (`Stats.validate_shield/1`); a
  mob caster has no shield and falls back to the plain batk base through the
  shared `damage_base: :shield` seam. On a connecting hit there is a
  `15 + 5×level`% chance to stun the target for 4.5 seconds, and the target is
  always knocked back `4 + level` cells away from the caster.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 250,
    name: :cr_shieldcharge,
    display_name: "Shield Charge",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 3,
    damage_base: :shield,
    sp_cost: [10, 10, 10, 10, 10]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @stun_duration 4_500

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_shield}
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition) do
    Stats.validate_shield(equipment)
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, {:unit, target}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 20 * level,
      damage_base: :shield,
      skip_crit: true,
      report_hit: true
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: hit?}} ->
        if hit?, do: apply_riders(caster, target, level)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp apply_riders(caster, target, level) do
    {unit_type, unit_id} = target_ref(target)
    Combat.knockback(unit_type, unit_id, caster.x, caster.y, knockback_distance(level))
    maybe_stun(caster, unit_type, unit_id, level)
    :ok
  end

  @spec knockback_distance(pos_integer()) :: pos_integer()
  defp knockback_distance(level), do: 4 + level

  defp maybe_stun(caster, unit_type, unit_id, level) do
    if :rand.uniform(100) <= 15 + 5 * level do
      {source_type, source_id} = source_ref(caster)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_stun,
        duration: @stun_duration,
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
