defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkSpiralpierce do
  @moduledoc """
  Spiral Pierce (LK_SPIRALPIERCE) is a spear/sword weight strike whose one
  calculated damage is repeated over five hits. A hit that deals damage to a
  living player, or to a monster that is not status immune, immobilises it
  with Ankle for one second through the ordinary status application.

  Renewal folds the 70% base and size adjustment into one integer rate, which
  can round by one point. Classic replaces a player's base with 8% of the
  weapon's weight raised by 50% per level, plus (STR / 10)^2, scaled 125% on
  small and 75% on large targets; the weapon's refine ATK joins after DEF.

  A monster has no weapon weight: its hit is calculated as a weapon attack on
  its ordinary base, forced neutral, and delivered as a long misc hit to every
  flag consumer. In renewal that base takes the level ratio; in classic it is
  the ordinary roll plus (STR / 10)^2 with the same small/large size fix, at
  100% and ignoring DEF.
  Charging Pierce's optional alteration is not modelled.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 397,
    name: :lk_spiralpierce,
    cast_cancel: false,
    requires: [],
    display_name: "Spiral Pierce",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 4,
    hit_count: 5,
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
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats
  alias Aesir.ZoneServer.Unit.Player.WeaponHand

  @behaviour Active

  @ankle_ms 1_000

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
         {weight, _refine} <-
           Stats.right_hand_weapon_stats(caster.stats.equipment, Map.values(caster.inventory)) do
      opts =
        if GameMode.mode() == :renewal,
          do: renewal_opts(caster, target.size, weight, level, definition),
          else: classic_opts(caster, target.size, weight, level, definition)

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
      mode_opts =
        if GameMode.mode() == :renewal,
          do: [skill_ratio: LevelModifier.skill_ratio(150 + 50 * level, caster.mob_data.level)],
          else: classic_mob_opts(caster, target.size)

      opts =
        attack_opts(definition, min(level, 5)) ++
          mode_opts ++ [element: :neutral, dmg_type: :misc]

      strike(caster, target_id, target, opts)
    end
  end

  # The ordinary non-player roll, the STR bonus and the Spiral size fix form
  # the base; DEF is ignored.
  defp classic_mob_opts(caster, size) do
    attacker = MobState.to_combatant(caster)
    {:ok, roll} = DamageInputs.non_player_base_attack(attacker, skill_id: definition().id)
    str_bonus = Integer.pow(div(attacker.base_stats.str, 10), 2)

    [base_damage: div((roll + str_bonus) * spiral_size_rate(size), 100), ignore_defense: true]
  end

  defp spiral_size_rate(:small), do: 125
  defp spiral_size_rate(:large), do: 75
  defp spiral_size_rate(_size), do: 100

  defp renewal_opts(caster, size, weight, level, definition) do
    size_rate = %{small: 130, medium: 115, large: 100}[size]

    attack_opts(definition, level) ++
      [
        weight_atk: div(weight, 10),
        base_atk_rate: div(70 * size_rate, 100),
        skill_ratio:
          LevelModifier.skill_ratio(150 + 50 * level, caster.stats.progression.base_level)
      ]
  end

  defp classic_opts(caster, size, weight, level, definition) do
    str_bonus = Integer.pow(div(Stats.get_effective_stat(caster.stats, :str), 10), 2)
    weighted = div(div(weight * 8, 100) * (100 + 50 * level), 100) + str_bonus

    attack_opts(definition, level) ++
      [
        base_damage: div(weighted * spiral_size_rate(size), 100),
        ignore_defense: true,
        ignore_size: true,
        refine_atk: right_refine_atk(caster.stats)
      ]
  end

  defp right_refine_atk(%Stats{right_hand: %WeaponHand{refine_atk: refine_atk}}), do: refine_atk
  defp right_refine_atk(_stats), do: 0

  defp attack_opts(definition, level) do
    [
      skill_id: definition.id,
      skill_level: level,
      hit_divisions: Definition.hit_count_at_level(definition, level),
      skip_crit: true,
      skip_range: true,
      report_hit: true
    ]
  end

  defp strike(caster, target_id, target, opts) do
    case Combat.execute_skill_attack(caster, target_id, opts) do
      {:ok, %{hit?: true} = hit} ->
        if Map.get(hit, :target_survives?, true) and ankle_target?(target) do
          type = caster.__struct__.get_unit_type(caster)
          id = caster.__struct__.get_unit_id(caster)

          _ =
            StatusInterpreter.apply_status(target.unit_type, target.unit_id, :sc_ankle,
              duration: @ankle_ms,
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

  # A player, or a monster that is not status immune.
  defp ankle_target?(%Combatant{unit_type: :player}), do: true

  defp ankle_target?(%Combatant{unit_type: :mob} = target),
    do: not target.status_immune

  defp ankle_target?(_target), do: false
end
