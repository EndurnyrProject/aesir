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
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 57,
    name: :kn_brandishspear,
    requires: [],
    display_name: "Brandish Spear",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    splash_radius: 2,
    sp_cost: List.duplicate(24, 10)

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @spear_types [:one_handed_spear, :two_handed_spear]
  @riding_bit Option.id(:riding)
  @knockback_distance 2

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
        skill_ratio: skill_ratio(level, combatant.base_stats.str),
        skip_crit: true,
        ranged: true
      ]

      caster
      |> Combat.execute_splash_attack({x, y}, definition.splash_radius, opts)
      |> Enum.each(&Combat.knockback(:mob, &1, caster.x, caster.y, @knockback_distance))

      {:ok, caster}
    end
  end

  @doc "The weapon-ratio percentage at `level` for a caster with `str` strength."
  @spec skill_ratio(pos_integer(), non_neg_integer()) :: pos_integer()
  def skill_ratio(level, str), do: 400 + 100 * level + str * 3

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
