defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspear do
  @moduledoc """
  Brandish Spear (KN_BRANDISHSPEAR). A mounted spear sweep over the lane
  running from the caster toward its target: five rows long and five cells
  wide, the nearest row level with the caster, hitting every enemy the caster
  can see in it and knocking each one 2 cells away from the caster.

  The cast itself is a no-damage cast that sweeps the area: it completes under
  stun or freeze, arms on-skill procs at its target, sends no cast visual of
  its own, and its hits arm no when-hit procs on the recipients. A player who
  casts it cannot change weapons for a second, unless already barred longer.

  Only usable mounted with a spear (one or two-handed) equipped; a mob
  caster bypasses both gates entirely, since mobs have no equipment or mount
  state.

  Renewal: the whole lane at 400% plus 100% per level plus 3 times STR, a
  long-range hit shown as three hits that split the damage, 24 SP, a 0.35 s
  fixed cast, 0.5 s delay, and 1 s cooldown.

  Pre-renewal: the lane grows with the level, two rows up to level 3 and one
  more row at levels 4, 7 and 10, each row its own sweep, the farthest first.
  The ratio is `r = 100 + 20 * level` plus, by row for a player caster, `r/2`
  (from level 4), `r/4` (from level 7) and `r/8` (at level 10) on the first two
  rows, `r/2` (from level 7) and `r/4` (at level 10) on the third, `r/2` (at
  level 10) on the fourth and nothing on the fifth; a monster's every row takes
  the first rows' bonus. One short-range hit, 12 SP, a 0.7 s variable cast,
  and no delay or cooldown.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 57,
    name: :kn_brandishspear,
    cast_cancel: false,
    requires: [],
    display_name: "Brandish Spear",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 2,
    splash_radius: 2,
    knockback: 2,
    hit_count: [renewal: -3, pre_renewal: 1],
    require_weapon: [:one_handed_spear, :two_handed_spear],
    sp_cost: [renewal: List.duplicate(24, 10), pre_renewal: List.duplicate(12, 10)],
    cast_time: [renewal: [], pre_renewal: List.duplicate(700, 10)],
    fixed_cast_time: [renewal: List.duplicate(350, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(1000, 10), pre_renewal: []],
    duration: List.duplicate(1000, 10)

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.CastendStrip
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @spear_types [:one_handed_spear, :two_handed_spear]
  @lane_length 5
  @riding_bit Option.id(:riding)

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, :requires_spear | :requires_riding}
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    with :ok <- check_weapon(caster) do
      check_riding(caster)
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, target, level, definition),
    do: cast_with_origin(caster, target, level, definition, :normal)

  @impl Active
  @spec cast_with_origin(
          Active.caster(),
          Active.target(),
          pos_integer(),
          Definition.t(),
          Active.cast_origin()
        ) :: {:ok, Active.caster()} | {:error, atom()}
  def cast_with_origin(caster, {:unit, target_id}, level, definition, origin) do
    with {:ok, _primary} <- Combat.resolve_combatant(target_id) do
      CastendStrip.start(
        caster,
        origin,
        :sc_stripweapon,
        Enum.at(definition.duration, level - 1)
      )

      str = caster_str(caster, caster.__struct__.to_combatant(caster))

      for {offset, length, row} <- sweeps(caster, level) do
        Combat.execute_line_attack(caster, target_id,
          skill_id: definition.id,
          skill_level: level,
          skill_ratio: skill_ratio(level, str, row),
          hit_divisions: Definition.hit_count_at_level(definition, level),
          skip_crit: true,
          ranged: GameMode.mode() == :renewal,
          length: length,
          width: definition.splash_radius,
          offset: offset,
          base_distance: definition.knockback,
          origin: {caster.x, caster.y},
          native_target_types: [:mob],
          delivery: delivery()
        )
      end

      {:ok, caster}
    end
  end

  # Each sweep is `{offset, length, row}`, `row` selecting the classic ratio
  # bonus. A classic monster's sweeps all take the first rows' bonus.
  defp sweeps(caster, level) do
    case GameMode.mode() do
      :renewal -> [{0, @lane_length, 0}]
      :pre_renewal -> classic_sweeps(match?(%PlayerState{}, caster), level)
    end
  end

  defp classic_sweeps(player?, level) do
    row = fn bonus_row -> if player?, do: bonus_row, else: 0 end

    Enum.filter(
      [
        level >= 10 and {@lane_length - 1, 1, row.(3)},
        level >= 7 and {@lane_length - 2, 1, row.(2)},
        level >= 4 and {@lane_length - 3, 1, row.(1)},
        {0, @lane_length - 3, 0}
      ],
      & &1
    )
  end

  # Renewal strikes every recipient unanimated; classic animates every recipient
  # but the targeted one.
  defp delivery do
    case GameMode.mode() do
      :renewal -> :direct
      :pre_renewal -> :splash
    end
  end

  # A player's STR includes job, equipment, and status bonuses; a mob's snapshot
  # already holds its final stats.
  defp caster_str(%PlayerState{stats: stats}, _combatant),
    do: PlayerStats.get_effective_stat(stats, :str)

  defp caster_str(_caster, combatant), do: combatant.base_stats.str

  @doc """
  The weapon-ratio percentage at `level` for a caster with `str` strength on
  the classic ratio `row` (0 to 3, nearest first): renewal
  `400 + 100 * level + 3 * STR` on every row, classic `r = 100 + 20 * level`
  plus the row's bonus.
  """
  @spec skill_ratio(pos_integer(), non_neg_integer(), 0..3) :: pos_integer()
  def skill_ratio(level, str, row \\ 0) do
    case GameMode.mode() do
      :renewal -> 400 + 100 * level + str * 3
      :pre_renewal -> classic_ratio(level, row)
    end
  end

  defp classic_ratio(level, row) do
    ratio = 100 + 20 * level

    bonus =
      case row do
        0 ->
          step(level > 3, div(ratio, 2)) + step(level > 6, div(ratio, 4)) +
            step(level > 9, div(ratio, 8))

        1 ->
          step(level > 6, div(ratio, 2)) + step(level > 9, div(ratio, 4))

        2 ->
          step(level > 9, div(ratio, 2))

        3 ->
          0
      end

    ratio + bonus
  end

  defp step(true, amount), do: amount
  defp step(false, _amount), do: 0

  @spec check_weapon(PlayerState.t()) :: :ok | {:error, :requires_spear}
  defp check_weapon(%PlayerState{stats: %{equipment: equipment}}) do
    if PlayerStats.weapon_type(equipment) in @spear_types do
      :ok
    else
      {:error, :requires_spear}
    end
  end

  @spec check_riding(PlayerState.t()) :: :ok | {:error, :requires_riding}
  defp check_riding(%PlayerState{option: option}) do
    if (option &&& @riding_bit) != 0 do
      :ok
    else
      {:error, :requires_riding}
    end
  end
end
