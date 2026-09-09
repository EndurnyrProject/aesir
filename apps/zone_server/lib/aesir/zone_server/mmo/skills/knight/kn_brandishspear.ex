defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnBrandishspear do
  @moduledoc """
  Brandish Spear (KN_BRANDISHSPEAR). A mounted spear sweep that hits the
  target and every enemy within 2 cells of it, knocking each hit target back
  away from the caster.

  Ratio scales `(400 + 100 * level + caster STR * 3)` percent, a single hit
  per connected target. Renewal classifies the swing as a ranged physical
  attack despite its melee cast range, so the damage path is told to force
  `is_short: false` rather than deriving it from the caster's (short) weapon
  range.

  Only usable mounted with a spear (one or two-handed) equipped; a mob
  caster bypasses both gates entirely, since mobs have no equipment or mount
  state.

  Renewal: 400% plus 100% per level plus 3 times STR, shown as three hits that split the damage, 24 SP, a 0.35 s fixed cast, 0.5 s delay, and 1 s cooldown. Pre-renewal: 100% plus 20% per level, one hit, 12 SP, a 0.7 s variable cast, and no delay or cooldown; the classic bonus bands that grow with the caster's distance to each target are not modelled. Both modes push 2 cells and need a spear and a mount.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 57,
    name: :kn_brandishspear,
    requires: [],
    display_name: "Brandish Spear",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 2,
    splash_radius: 2,
    knockback: 2,
    hit_count: [renewal: 3, pre_renewal: 1],
    require_weapon: [:one_handed_spear, :two_handed_spear],
    sp_cost: [renewal: List.duplicate(24, 10), pre_renewal: List.duplicate(12, 10)],
    cast_time: [renewal: [], pre_renewal: List.duplicate(700, 10)],
    fixed_cast_time: [renewal: List.duplicate(350, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 10), pre_renewal: []],
    cooldown: [renewal: List.duplicate(1000, 10), pre_renewal: []]

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @spear_types [:one_handed_spear, :two_handed_spear]
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
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: {x, y}}} <- Combat.resolve_combatant(target_id) do
      combatant = caster.__struct__.to_combatant(caster)

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: skill_ratio(level, caster_str(caster, combatant)),
        display_hit_count: definition.hit_count,
        skip_crit: true,
        ranged: true,
        base_distance: definition.knockback,
        origin: {caster.x, caster.y},
        native_target_types: [:mob]
      ]

      _ = Combat.execute_splash_attack(caster, {x, y}, definition.splash_radius, opts)
      {:ok, caster}
    end
  end

  # A player's STR includes job, equipment, and status bonuses; a mob's snapshot
  # already holds its final stats.
  defp caster_str(%PlayerState{stats: stats}, _combatant),
    do: PlayerStats.get_effective_stat(stats, :str)

  defp caster_str(_caster, combatant), do: combatant.base_stats.str

  @doc """
  The weapon-ratio percentage at `level` for a caster with `str` strength:
  renewal `400 + 100 * level + 3 * STR`, classic `100 + 20 * level`.
  """
  @spec skill_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(level, str) do
    case GameMode.mode() do
      :renewal -> 400 + 100 * level + str * 3
      :pre_renewal -> 100 + 20 * level
    end
  end

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
