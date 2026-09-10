defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung do
  @moduledoc """
  Ki Explosion (MO_BALKYOUNG). A weapon splash that sacrifices HP for one
  strike, then knocks back and may stun every damaged target.

  Renewal: 800 percent for 200 HP and 40 SP with a 4.5 s stun on the pushed
  neighbours. Pre-renewal: 300 percent for 10 HP and 20 SP with a 5 s stun. The
  70% stun chance, one-cell splash, five-cell push, and 2 s delay are shared.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1_016,
    name: :mo_balkyoung,
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
    quest_owner_job: :monk

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @impl Active
  def cast(caster, {:unit, primary_target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(primary_target_id) do
      caster
      |> Combat.execute_splash_attack(
        {x, y},
        definition.splash_radius,
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: Formulas.ki_explosion_ratio(),
        skip_crit: true,
        typed_results: true,
        base_distance: definition.knockback,
        origin: {x, y},
        native_target_types: [:player, :mob, :homunculus]
      )
      |> Enum.each(&apply_splash_effects(caster, &1))

      {:ok, caster}
    end
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
    if :rand.uniform(100) <= Formulas.ki_explosion_stun_rate() do
      {caster_type, caster_id} = caster_identity(caster)

      StatusInterpreter.apply_status(
        unit_type,
        target_id,
        :sc_stun,
        duration: Formulas.ki_explosion_stun_duration(),
        caster_id: caster_id,
        source_type: caster_type
      )
    end

    :ok
  end

  # Generic caster identity for the stun's source, so the splash rider works for
  # a mob caster (Ki Explosion is an imported mob skill) as well as a player. A
  # player caster resolves to `{:player, character_id}`, which is exactly the
  # `caster_id` and default `source_type` the player path already produced.
  defp caster_identity(%MobState{instance_id: id}), do: {:mob, id}
  defp caster_identity(%{character_id: id}), do: {:player, id}
end
