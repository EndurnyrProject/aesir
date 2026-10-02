defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaShieldchain do
  @moduledoc """
  Rapid Smiting (PA_SHIELDCHAIN). Five displayed hits on the shield base
  (attack plus 4 per refine plus the shield's weight), with a flat +20 to the
  hit rate after the clamp. A player needs a shield; a mob caster falls back to
  the plain attack base. The interpreter enforces the per-level reach and the
  attack skips the melee range check. 28 to 40 SP, 1 s after-cast delay.

  Renewal: ratio `300 + 200 * level` plus the shield's weight/10 and 4 per
  refine, all scaled by the caster's base level over 100; reach 7/7/9/9/11
  cells; 0.8 s cast plus 0.2 s fixed. Pre-renewal: ratio `100 + 30 * level`;
  reach 4; 1 s cast. Element handling follows Shield Boomerang: renewal's
  forced-neutral step after the weapon element and pre-renewal's DEF applied
  before the ratio are not modelled. Imperial Guard interactions are out of
  scope.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 480,
    name: :pa_shieldchain,
    requires: [],
    display_name: "Rapid Smiting",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_base: :shield,
    hit_count: 5,
    range: [renewal: [7, 7, 9, 9, 11], pre_renewal: List.duplicate(4, 5)],
    sp_cost: [28, 31, 34, 37, 40],
    cast_time: [renewal: List.duplicate(800, 5), pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(200, 5), pre_renewal: List.duplicate(0, 5)],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_shield}
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition),
    do: PlayerStats.validate_shield(equipment)

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(caster, level),
      damage_base: :shield,
      display_hit_count: 5,
      hit_rate_bonus_flat: 20,
      skip_crit: true,
      skip_range: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @doc """
  The per-mode damage ratio. Renewal folds the worn shield's weight and refine
  into the ratio and scales by base level; pre-renewal is a flat per-level
  table. A mob or a shieldless caster contributes no shield bonus.
  """
  @spec skill_ratio(Active.caster(), pos_integer()) :: pos_integer()
  def skill_ratio(caster, level) do
    case GameMode.mode() do
      :renewal ->
        {weight, refine} = shield_stats(caster)
        div((300 + 200 * level + div(weight, 10) + 4 * refine) * base_level(caster), 100)

      :pre_renewal ->
        100 + 30 * level
    end
  end

  defp shield_stats(%PlayerState{stats: %{equipment: equipment}, inventory: inventory}),
    do: PlayerStats.shield_stats(equipment, Map.values(inventory)) || {0, 0}

  defp shield_stats(_caster), do: {0, 0}

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level
end
