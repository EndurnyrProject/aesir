defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicblow do
  @moduledoc """
  Sonic Blow (AS_SONICBLOW). One katar strike displayed as eight hits, stunning
  10 plus 2 per level percent of the time, for 16 to 34 SP at 1 cell.

  Renewal: 200% plus 100% per level, half again below half HP; Sonic Acceleration
  adds 90% HIT and 90% damage; a 4.5 s stun and a 1 s cooldown with no delay.
  Pre-renewal: 300% plus 50% per level; Sonic Acceleration adds a tenth of the
  damage and 50% HIT; a 5 s stun and a 2 s delay with no cooldown.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 136,
    name: :as_sonicblow,
    requires: [],
    display_name: "Sonic Blow",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 1,
    hit_count: 1,
    sp_cost: Enum.to_list(16..34//2),
    after_cast_delay: [renewal: [], pre_renewal: List.duplicate(2_000, 10)],
    cooldown: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    duration: [renewal: List.duplicate(4_500, 10), pre_renewal: List.duplicate(5_000, 10)],
    require_weapon: [:katar]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicaccel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition) do
    if Stats.weapon_type(equipment) == :katar, do: :ok, else: {:error, :wrong_weapon}
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok
  def validate(_caster, _target, _level, _definition), do: {:error, :invalid_caster}

  @impl Active
  def cast(caster, {:unit, target_ref}, level, definition) do
    with {:ok, _pid, target, target_type} <- TargetResolver.resolve(target_ref) do
      accelerated? = accelerated?(caster)

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: skill_ratio(level, below_half?(target), accelerated?),
        accelerated: accelerated?,
        acceleration: acceleration(),
        hit_count: 1,
        display_hit_count: 8,
        skip_crit: true,
        report_hit: true,
        skip_range: true
      ]

      case Combat.execute_sonic_blow_attack(caster, target_ref, opts) do
        {:ok, %{hit?: true}} ->
          apply_stun(caster, target_type, target_ref, level, definition)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc """
  The weapon ratio. Renewal: 200% plus 100% per level, half again against a target
  below half HP (Sonic Acceleration is applied later as a 190% damage rate).
  Pre-renewal: 300% plus 50% per level, plus a tenth with Sonic Acceleration.
  """
  @spec skill_ratio(pos_integer(), boolean(), boolean()) :: pos_integer()
  def skill_ratio(level, below_half?, accelerated?) do
    case GameMode.mode() do
      :renewal ->
        ratio = 200 + 100 * level
        if below_half?, do: div(ratio * 3, 2), else: ratio

      :pre_renewal ->
        ratio = 300 + 50 * level
        if accelerated?, do: ratio + div(ratio, 10), else: ratio
    end
  end

  # Sonic Acceleration: renewal adds 90% HIT and 90% damage at delivery; classic adds
  # 50% HIT (its damage share already sits in the ratio).
  defp acceleration do
    case GameMode.mode() do
      :renewal -> %{hit_rate: 90, damage_rate: 190}
      :pre_renewal -> %{hit_rate: 50, damage_rate: 100}
    end
  end

  defp accelerated?(%PlayerState{stats: %{progression: %{learned_skills: learned}}}) do
    Map.get(learned, AsSonicaccel.definition().id, 0) > 0
  end

  defp accelerated?(_caster), do: false

  defp below_half?(%{stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}}),
    do: hp * 2 < max_hp

  defp below_half?(%{hp: hp, max_hp: max_hp}), do: hp * 2 < max_hp

  defp apply_stun(caster, target_type, target_ref, level, definition) do
    {source_type, caster_id} = caster_ref(caster)

    _ =
      StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_stun,
        duration: Enum.at(definition.duration, level - 1),
        success_rate: 10 + 2 * level,
        caster_id: caster_id,
        source_type: source_type
      )

    :ok
  end

  defp caster_ref(%PlayerState{character_id: caster_id}), do: {:player, caster_id}
  defp caster_ref(%MobState{instance_id: caster_id}), do: {:mob, caster_id}

  defp unit_id({_unit_type, unit_id}), do: unit_id
  defp unit_id(unit_id), do: unit_id
end
