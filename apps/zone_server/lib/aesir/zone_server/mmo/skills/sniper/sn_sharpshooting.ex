defmodule Aesir.ZoneServer.Mmo.Skills.Sniper.SnSharpshooting do
  @moduledoc """
  Focused Arrow Strike is a bow-and-arrow physical strike that rolls critical
  before flee. Renewal adds 30 critical points and uses a radius-2 target-centred
  splash including enemy traps, with normal weapon variance even on a critical.
  Its player ratio is `(300 + 300 * level) * BaseLv / 100` percent.

  Pre-renewal adds 20 critical points and strikes a 14-long, 3-wide snapped lane.
  An empty hit list falls back to the clicked target; player damage is
  `200 + 50 * level` percent. Mobs use that flat ratio in renewal and for the
  classic fallback, but `140 * level` percent for classic lane targets.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 382,
    name: :sn_sharpshooting,
    display_name: "Focused Arrow Strike",
    max_level: 5,
    requires: [],
    target_type: :target_enemy,
    damage_type: :damage,
    range: [renewal: 11, pre_renewal: 9],
    splash_radius: [renewal: 2, pre_renewal: 0],
    require_weapon: [:bow],
    requires_ammo: true,
    sp_cost: [renewal: [16, 18, 20, 22, 24], pre_renewal: [18, 21, 24, 27, 30]],
    cast_time: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(2000, 5)],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1500, 5)],
    cooldown: [renewal: List.duplicate(150, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skills.Sniper.Formulas
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) :: :ok
  def validate(%PlayerState{}, _target, _level, _definition), do: :ok
  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with :ok <- strike(caster, target_id, level, definition), do: {:ok, caster}
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    strike(caster, {type, id}, level, definition)
  end

  defp strike(caster, target, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      critical: true,
      critical_rate_bonus: Formulas.sharpshooting_crit_bonus(),
      ranged: true
    ]

    case GameMode.mode() do
      :renewal ->
        with {:ok, %{position: center} = primary} <- Combat.resolve_combatant(target) do
          Combat.execute_splash_attack(
            caster,
            center,
            definition.splash_radius,
            opts ++
              [
                skill_ratio: ratio(caster, level, false),
                critical_max_weapon: false,
                target_skill_units: true,
                delivery: {:splash, {primary.unit_type, primary.unit_id}}
              ]
          )

          :ok
        end

      :pre_renewal ->
        case Combat.execute_line_attack(
               caster,
               target,
               opts ++
                 [skill_ratio: ratio(caster, level, true), length: 14, width: 1, delivery: :area]
             ) do
          [] ->
            Combat.execute_skill_attack(
              caster,
              target,
              opts ++ [skill_ratio: ratio(caster, level, false), skip_range: true]
            )

          _connected ->
            :ok
        end
    end
  end

  defp ratio(%PlayerState{stats: stats}, level, _path_target?),
    do: Formulas.sharpshooting_ratio(level, stats.progression.base_level)

  defp ratio(%MobState{}, level, path_target?),
    do: Formulas.sharpshooting_mob_ratio(level, path_target?)
end
