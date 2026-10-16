defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung do
  @moduledoc """
  Ki Explosion (MO_BALKYOUNG). A weapon strike that sacrifices HP; when it deals
  damage, the enemies around its target are pushed away and may be stunned.

  The struck target is neither pushed nor stunned. Each other enemy within one
  cell of it takes no damage: it is pushed five cells away from the caster and
  then stunned with a 70% chance.

  Renewal: 800 percent for 200 HP and 40 SP with a 4.5 s stun. Pre-renewal: 300
  percent for 10 HP and 20 SP with a 5 s stun. The 2 s delay is shared.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1_016,
    name: :mo_balkyoung,
    ignore_atk_card: [renewal: false, pre_renewal: true],
    requires: [],
    display_name: "Ki Explosion",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    knockback: 5,
    splash_radius: 1,
    hp_cost: [renewal: [200], pre_renewal: [10]],
    sp_cost: [renewal: [40], pre_renewal: [20]],
    duration: [renewal: [4_500], pre_renewal: [5_000]],
    after_cast_delay: [2_000],
    quest_skill: true,
    quest_owner_job: :monk,
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, primary_target_id}, level, definition) do
    with {:ok, primary} <- Combat.resolve_combatant(primary_target_id) do
      case Combat.execute_skill_attack(caster, primary_target_id,
             skill_id: definition.id,
             skill_level: level,
             skill_ratio: Formulas.ki_explosion_ratio(),
             skip_crit: true,
             skip_range: true,
             equipment_blow: false,
             report_hit: true
           ) do
        {:ok, %{damage: damage}} when damage > 0 -> push_neighbours(caster, primary, definition)
        _no_damage -> :ok
      end

      {:ok, caster}
    end
  end

  defp push_neighbours(caster, primary, definition) do
    combatant = caster.__struct__.to_combatant(caster)
    {cx, cy} = combatant.position

    combatant.map_name
    |> Combat.splash_targets(primary.position, definition.splash_radius, combatant)
    |> Enum.reject(&(&1 == {primary.unit_type, primary.unit_id}))
    |> Enum.each(fn {unit_type, target_id} = target_ref ->
      Knockback.knockback(unit_type, target_id, cx, cy, definition.knockback,
        source_boss?: combatant.class == :boss
      )

      OnHitEffects.direct(combatant, target_ref, BattleFlags.type_bit(:misc), definition.id)
      apply_splash_effects(caster, target_ref)
    end)
  end

  defp apply_splash_effects(caster, {unit_type, target_id} = target_ref) do
    case TargetResolver.resolve(target_ref) do
      {:ok, _pid, _state, ^unit_type} ->
        apply_resolved_splash_effects(caster, unit_type, target_id)

      {:error, _reason} ->
        :ok
    end
  end

  defp apply_resolved_splash_effects(caster, unit_type, target_id) do
    {caster_type, caster_id} = caster_identity(caster)

    StatusInterpreter.apply_status(
      unit_type,
      target_id,
      :sc_stun,
      duration: Formulas.ki_explosion_stun_duration(),
      success_rate: Formulas.ki_explosion_stun_rate(),
      caster_id: caster_id,
      source_type: caster_type
    )

    :ok
  end

  # Generic caster identity for the stun's source, so the splash rider works for
  # a mob caster (Ki Explosion is an imported mob skill) as well as a player. A
  # player caster resolves to `{:player, character_id}`, which is exactly the
  # `caster_id` and default `source_type` the player path already produced.
  defp caster_identity(%MobState{instance_id: id}), do: {:mob, id}
  defp caster_identity(%{character_id: id}), do: {:player, id}
end
