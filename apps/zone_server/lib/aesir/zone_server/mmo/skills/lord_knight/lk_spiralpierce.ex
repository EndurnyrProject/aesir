defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierce do
  @moduledoc """
  Spiral Pierce (LK_SPIRALPIERCE) is a spear/sword weight strike displayed as
  five hits, rooting a non-boss target for one second on a connecting hit.

  Renewal folds the 70% base and size adjustment into one integer rate, which
  can round by one point. Pre-renewal's refine bonus rides `bonus_atk` under
  ATK rate rather than being added after that rate. Mob casts use physical
  ranged neutral damage rather than the reference misc attack. Charging
  Pierce's optional alteration is not modelled.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 397,
    name: :lk_spiralpierce,
    requires: [],
    display_name: "Spiral Pierce",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 4,
    hit_count: 1,
    sp_cost: [18, 21, 24, 27, 30],
    require_weapon: [
      renewal: [:one_handed_sword, :two_handed_sword, :one_handed_spear, :two_handed_spear],
      pre_renewal: [:one_handed_spear, :two_handed_spear]
    ],
    cast_time: [renewal: [50, 100, 150, 200, 250], pre_renewal: [300, 500, 700, 900, 1_000]],
    fixed_cast_time: [renewal: List.duplicate(300, 5), pre_renewal: List.duplicate(0, 5)],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [1_200, 1_400, 1_600, 1_800, 2_000]
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :wrong_weapon}
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, definition) do
    if Stats.weapon_type(equipment) in definition.require_weapon,
      do: :ok,
      else: {:error, :wrong_weapon}
  end

  def validate(%MobState{}, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(%PlayerState{} = caster, {:unit, target_id}, level, definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id),
         {weight, refine} <-
           Stats.right_hand_weapon_stats(caster.stats.equipment, Map.values(caster.inventory)) do
      opts =
        if GameMode.mode() == :renewal,
          do: renewal_opts(caster, target.size, weight, level, definition),
          else: classic_opts(weight, refine, level, definition)

      case strike(caster, target_id, target, opts) do
        :ok -> {:ok, caster}
        {:error, _reason} = error -> error
      end
    else
      nil -> {:error, :wrong_weapon}
      {:error, _reason} = error -> error
    end
  end

  def cast(%MobState{} = caster, {:unit, target_id}, level, definition) do
    case mob_strike(caster, target_id, level, definition) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @impl Active
  @spec mob_cast(MobState.t(), term(), pos_integer(), Definition.t(), map()) ::
          :ok | {:error, atom()}
  def mob_cast(%MobState{} = caster, {:unit, type, id}, level, definition, _row) do
    mob_strike(caster, {type, id}, level, definition)
  end

  defp mob_strike(caster, target_id, level, definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id) do
      ratio =
        if GameMode.mode() == :renewal,
          do: div((150 + 50 * level) * caster.mob_data.level, 100),
          else: 100 + 50 * level

      opts =
        attack_opts(definition, min(level, 5)) ++
          [skill_ratio: ratio, element: :neutral, ranged: true]

      strike(caster, target_id, target, opts)
    end
  end

  defp renewal_opts(caster, size, weight, level, definition) do
    size_rate = %{small: 130, medium: 115, large: 100}[size]

    attack_opts(definition, level) ++
      [
        weight_atk: div(weight, 10),
        base_atk_rate: div(70 * size_rate, 100),
        skill_ratio: div((150 + 50 * level) * caster.stats.progression.base_level, 100)
      ]
  end

  defp classic_opts(weight, refine, level, definition) do
    attack_opts(definition, level) ++
      [
        base_damage: div(weight * 8, 100),
        skill_ratio: 100 + 50 * level,
        ignore_defense: true,
        ignore_size: true,
        bonus_atk: refine
      ]
  end

  defp attack_opts(definition, level) do
    [
      skill_id: definition.id,
      skill_level: level,
      display_hit_count: 5,
      skip_crit: true,
      skip_range: true,
      report_hit: true
    ]
  end

  defp strike(caster, target_id, target, opts) do
    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true}} ->
        if target.class != :boss do
          type = caster.__struct__.get_unit_type(caster)
          id = caster.__struct__.get_unit_id(caster)

          _ =
            StatusInterpreter.apply_status(target.unit_type, target.unit_id, :sc_stop,
              duration: 1_000,
              bypass_resistance: true,
              caster_id: id,
              source_type: type
            )
        end

        :ok

      {:ok, %{hit?: false}} ->
        :ok

      {:error, _reason} = error ->
        error
    end
  end
end
