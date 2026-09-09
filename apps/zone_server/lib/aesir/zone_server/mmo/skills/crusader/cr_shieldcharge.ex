defmodule Aesir.ZoneServer.Mmo.Skills.Crusader.CrShieldcharge do
  @moduledoc """
  Shield Charge (CR_SHIELDCHARGE). A single shield bash at 3 cells for 10 SP:
  100% plus 20% per level of the shield damage base, knocking the target 4 plus
  level cells back and stunning it 15% plus 5% per level of the time. A player
  needs a shield; a mob caster falls back to the plain attack base.

  Renewal stuns for 4.5 s; pre-renewal for 5 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 250,
    name: :cr_shieldcharge,
    requires: [],
    display_name: "Shield Charge",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 3,
    damage_base: :shield,
    sp_cost: [10, 10, 10, 10, 10],
    duration: [renewal: List.duplicate(4_500, 5), pre_renewal: List.duplicate(5_000, 5)]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

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
      report_hit: true,
      base_distance: knockback_distance(level),
      origin: {caster.x, caster.y},
      native_target_types: [:player, :mob, :homunculus]
    ]

    case Combat.execute_skill_attack(caster, target, opts) do
      {:ok, %{hit?: hit?}} ->
        if hit?, do: apply_riders(caster, target, level, definition)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp apply_riders(caster, target, level, definition) do
    {unit_type, unit_id} = target_ref(target)
    maybe_stun(caster, unit_type, unit_id, level, Enum.at(definition.duration, level - 1))
    :ok
  end

  @spec knockback_distance(pos_integer()) :: pos_integer()
  defp knockback_distance(level), do: 4 + level

  defp maybe_stun(caster, unit_type, unit_id, level, duration) do
    if :rand.uniform(100) <= 15 + 5 * level do
      {source_type, source_id} = source_ref(caster)

      StatusInterpreter.apply_status(unit_type, unit_id, :sc_stun,
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
