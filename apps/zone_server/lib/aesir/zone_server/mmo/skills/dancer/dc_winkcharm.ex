defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcWinkcharm do
  @moduledoc "Wink of Charm (DC_WINKCHARM)."

  use Aesir.ZoneServer.Mmo.Skill,
    quest_skill: true,
    quest_owner_job: :dancer,
    id: 1011,
    name: :dc_winkcharm,
    display_name: "Wink of Charm",
    max_level: 1,
    target_type: :target_any,
    damage_type: :no_damage,
    range: 9,
    sp_cost: [40],
    cast_time: [800],
    fixed_cast_time: [200],
    after_cast_delay: [2_000],
    cooldown: [10_000],
    duration: [10_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @eligible_races [:demon, :demi_human, :angel, :player_human, :player_doram]

  @impl Active
  def validate(caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, _unit_type} <- TargetResolver.resolve(target_id),
         :ok <- reject_boss(target),
         {:ok, combatant} <- Combat.resolve_combatant(target_id),
         :ok <- validate_race(combatant.race) do
      Targeting.validate_enemy(caster, target)
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp reject_boss(target) do
    if target.__struct__.is_boss?(target), do: {:error, :boss_immune}, else: :ok
  end

  defp validate_race(race) when race in @eligible_races, do: :ok
  defp validate_race(_race), do: {:error, :invalid_target_race}

  @impl Active
  def cast(%PlayerState{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_id),
         {:ok, target} <- Combat.resolve_combatant(target_id) do
      duration = Enum.at(definition.duration, level - 1)

      apply_effect(
        target_type,
        target_id,
        target,
        caster_id,
        caster.stats.progression.base_level,
        duration
      )

      {:ok, caster}
    end
  end

  defp apply_effect(:mob, target_id, target, caster_id, caster_level, duration) do
    StatusInterpreter.apply_status(:mob, target_id, :sc_winkcharm,
      duration: duration,
      success_rate: caster_level - target.progression.base_level + 40,
      caster_id: caster_id
    )
  end

  defp apply_effect(:player, target_id, _target, caster_id, _caster_level, duration) do
    StatusInterpreter.apply_status(:player, target_id, :sc_confusion,
      duration: duration,
      success_rate: 100,
      caster_id: caster_id
    )
  end
end
