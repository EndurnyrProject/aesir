defmodule Aesir.ZoneServer.Mmo.Skills.Dancer.DcWinkcharm do
  @moduledoc """
  Wink of Charm (DC_WINKCHARM). A quest skill charming a non-boss demon,
  demi-human, angel, or player at 9 cells for 40 SP with a 2 s delay. Monsters are
  charmed for 10 s at caster level minus target level plus 40 percent in both
  modes; a charmed monster then takes a zero-damage ranged normal weapon hit
  from the caster, which may make it switch its target to the caster.

  Renewal: a 0.8 s cast plus 0.2 s fixed, a 10 s cooldown, and players are
  confused and hallucinating for 10 s outright. Pre-renewal: a 1 s cast, no
  cooldown, and players are confused for 30 s at a 10 percent chance, gaining the
  10 s charm only when the confusion lands.

  Both modes: a boss target is refused before the cast begins; the target's
  race and enemy relation are checked when the cast ends.
  """

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
    cast_time: [renewal: [800], pre_renewal: [1_000]],
    fixed_cast_time: [renewal: [200], pre_renewal: []],
    after_cast_delay: [2_000],
    cooldown: [renewal: [10_000], pre_renewal: []],
    duration: [renewal: [10_000], pre_renewal: [30_000]],
    damage_kind: :misc

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @eligible_races [:demon, :demi_human, :angel, :player_human, :player_doram]
  @charm_duration 10_000

  # A charmed monster takes a zero-damage normal ranged weapon hit.
  @charm_hit_flag BattleFlags.build(:weapon, :long, false)

  @doc """
  A player's use on a boss is refused before the cast begins, replying that
  the target cannot be affected.
  """
  @impl Active
  def skilluse_check(%PlayerState{}, {:unit, target_id}, _level, _definition) do
    case TargetResolver.resolve(target_id) do
      {:ok, _pid, target, _unit_type} -> reject_boss(target)
      {:error, _reason} -> {:error, :target_not_found}
    end
  end

  def skilluse_check(_caster, _target, _level, _definition), do: :ok

  @doc """
  When the cast ends the target must be a demon, demi-human, angel or player,
  then an enemy; a dead target passes here and the effect is skipped once the
  cost is paid.
  """
  @impl Active
  def validate(caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, _unit_type} <- TargetResolver.resolve(target_id),
         {:ok, combatant} <- Combat.resolve_combatant(target_id),
         :ok <- validate_race(combatant.race) do
      Targeting.validate_enemy_relation_allow_dead(caster, target)
    end
  end

  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_target}

  defp reject_boss(target) do
    if target.__struct__.is_boss?(target), do: {:error, :to_target}, else: :ok
  end

  defp validate_race(race) when race in @eligible_races, do: :ok
  defp validate_race(_race), do: {:error, :invalid_target_race}

  @impl Active
  def cast(%PlayerState{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with {:ok, _pid, _target, target_type} <- TargetResolver.resolve(target_id),
         {:ok, target} <- Combat.resolve_combatant(target_id) do
      duration = Enum.at(definition.duration, level - 1)

      charmed =
        apply_effect(
          target_type,
          target_id,
          target,
          caster_id,
          caster.stats.progression.base_level,
          duration
        )

      if target_type == :mob and charmed == :ok,
        do: {:ok, Combat.execute_zero_damage_hit(caster, target_id, @charm_hit_flag)},
        else: {:ok, caster}
    end
  end

  defp apply_effect(:mob, target_id, target, caster_id, caster_level, _duration) do
    StatusInterpreter.apply_status(:mob, target_id, :sc_winkcharm,
      duration: @charm_duration,
      success_rate: caster_level - target.progression.base_level + 40,
      caster_id: caster_id
    )
  end

  defp apply_effect(:player, target_id, _target, caster_id, _caster_level, duration) do
    case GameMode.mode() do
      :renewal ->
        StatusInterpreter.apply_status(:player, target_id, :sc_confusion,
          duration: duration,
          success_rate: 100,
          caster_id: caster_id
        )

        StatusInterpreter.apply_status(:player, target_id, :sc_hallucination,
          duration: @charm_duration,
          success_rate: 100,
          caster_id: caster_id
        )

      :pre_renewal ->
        confused =
          StatusInterpreter.apply_status(:player, target_id, :sc_confusion,
            duration: duration,
            success_rate: 10,
            caster_id: caster_id
          )

        if confused == :ok do
          StatusInterpreter.apply_status(:player, target_id, :sc_winkcharm,
            duration: @charm_duration,
            caster_id: caster_id
          )
        end
    end
  end
end
