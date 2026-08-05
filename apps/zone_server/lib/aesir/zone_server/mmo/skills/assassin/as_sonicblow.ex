defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsSonicblow do
  @moduledoc "Sonic Blow (AS_SONICBLOW), one primary weapon hit displayed as eight."

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
    cooldown: List.duplicate(1_000, 10),
    require_weapon: [:katar]

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
        skill_ratio: skill_ratio(level, below_half?(target)),
        accelerated: accelerated?,
        hit_count: 1,
        display_hit_count: 8,
        skip_crit: true,
        report_hit: true,
        skip_range: true
      ]

      case Combat.execute_sonic_blow_attack(caster, target_ref, opts) do
        {:ok, %{hit?: true}} ->
          apply_stun(caster, target_type, target_ref, level)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc "Returns Sonic Blow's Renewal weapon ratio before Sonic Acceleration."
  @spec skill_ratio(pos_integer(), boolean()) :: pos_integer()
  def skill_ratio(level, below_half?) do
    ratio = 200 + 100 * level
    if below_half?, do: div(ratio * 3, 2), else: ratio
  end

  defp accelerated?(%PlayerState{stats: %{progression: %{learned_skills: learned}}}) do
    Map.get(learned, AsSonicaccel.definition().id, 0) > 0
  end

  defp accelerated?(_caster), do: false

  defp below_half?(%{stats: %{current_state: %{hp: hp}, derived_stats: %{max_hp: max_hp}}}),
    do: hp * 2 < max_hp

  defp below_half?(%{hp: hp, max_hp: max_hp}), do: hp * 2 < max_hp

  defp apply_stun(caster, target_type, target_ref, level) do
    {source_type, caster_id} = caster_ref(caster)

    _ =
      StatusInterpreter.apply_status(target_type, unit_id(target_ref), :sc_stun,
        duration: 4_500,
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
