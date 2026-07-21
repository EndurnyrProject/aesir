defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoBalkyoung do
  @moduledoc """
  Ki Explosion (MO_BALKYOUNG). A weapon splash that sacrifices HP for an
  800-percent strike, then knocks back and may stun every damaged target.

  Renewal rAthena defines one target hit with a one-cell splash, five-cell
  knockback, 200 HP and 40 SP costs, a 4,500ms stun duration, and a 2,000ms
  after-cast delay.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1_016,
    name: :mo_balkyoung,
    display_name: "Ki Explosion",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    knockback: 5,
    splash_radius: 1,
    hp_cost: [200],
    sp_cost: [40],
    duration: [4_500],
    after_cast_delay: [2_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Monk.Formulas
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

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
        skip_crit: true
      )
      |> Enum.each(&apply_splash_effects(caster, &1, x, y, definition))

      {:ok, caster}
    end
  end

  defp apply_splash_effects(caster, target_id, x, y, definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, _state, unit_type} ->
        apply_resolved_splash_effects(caster, unit_type, target_id, x, y, definition)

      {:error, _reason} ->
        :ok
    end
  end

  defp apply_resolved_splash_effects(caster, unit_type, target_id, x, y, definition) do
    _ = Combat.knockback(unit_type, target_id, x, y, definition.knockback)

    if :rand.uniform(100) <= Formulas.ki_explosion_stun_rate() do
      StatusInterpreter.apply_status(
        unit_type,
        target_id,
        :sc_stun,
        duration: Formulas.ki_explosion_stun_duration(),
        caster_id: caster.character_id
      )
    end

    :ok
  end
end
