defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearboomerang do
  @moduledoc """
  Spear Boomerang (KN_SPEARBOOMERANG). Single-target physical spear throw that
  reaches well past melee range.

  Single-hit weapon damage at `(100 + 50 * level)%` ATK. The skill's own reach
  grows with level (3/5/7/9/11 cells), declared as a per-level `range` list so
  the interpreter's own built-in range gate (`Interpreter.check_range/4`, used
  by both the cast validation chain and the walk-to-range movement helper)
  enforces the correct cell count for the cast level directly - no per-skill
  range override needed. `skip_range: true` is passed to the attack so the
  combat layer's own distance check - which gates on the caster's *melee*
  spear range - does not reject a throw beyond it; the interpreter remains the
  sole range authority for this skill, matching the convention direct-range
  magic skills use for the same reason.

  A player must have a spear (one or two-handed) equipped to cast it at all;
  a mob casting it is not gated on weapon, since mobs have no equipment.

  The equipped-weapon-driven long-range attack bonus (`bLongAtkRate`) does not
  apply here: it keys off the caster's weapon type, and a spear is a melee
  weapon regardless of this skill's own extended reach, so no reclassification
  is needed in the damage pipeline.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 59,
    name: :kn_spearboomerang,
    requires: [],
    display_name: "Spear Boomerang",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: [3, 5, 7, 9, 11],
    sp_cost: List.duplicate(10, 5)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @spear_types [:one_handed_spear, :two_handed_spear]

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(caster, _target, _level, _definition), do: check_weapon(caster)

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 50 * level,
      skip_crit: true,
      skip_range: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  @spec check_weapon(Active.caster()) :: :ok | {:error, :requires_spear}
  defp check_weapon(%PlayerState{stats: %{equipment: equipment}}) do
    if PlayerStats.weapon_type(equipment) in @spear_types do
      :ok
    else
      {:error, :requires_spear}
    end
  end

  defp check_weapon(_caster), do: :ok
end
