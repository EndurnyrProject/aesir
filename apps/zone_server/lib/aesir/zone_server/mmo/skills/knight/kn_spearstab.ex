defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnSpearstab do
  @moduledoc """
  Spear Stab (KN_SPEARSTAB). A spear thrust that pierces the straight line
  between the Knight and the target.

  Every living enemy standing on the line of cells from the caster to the
  target's cell (inclusive of the target's own cell) takes a single hit for
  `(100 + 20 * level)%` of the caster's weapon attack; an enemy standing off
  that line, even one closer to the caster, is untouched. In renewal the
  classic knockback-6 push was dropped: every hit lands in place, and none of
  the struck targets is displaced.

  Only usable with a spear equipped. Mobs bypass the weapon gate since they
  cast this skill through their mob-skill rows rather than an equipped item.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 58,
    name: :kn_spearstab,
    display_name: "Spear Stab",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    sp_cost: List.duplicate(9, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @spear_weapons [:one_handed_spear, :two_handed_spear]

  @impl Active
  def validate(%PlayerState{} = caster, _target, _level, _definition) do
    if PlayerStats.weapon_type(caster.stats.equipment) in @spear_weapons do
      :ok
    else
      {:error, :requires_spear}
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: 100 + 20 * level,
      skip_crit: true
    ]

    Combat.execute_line_attack(caster, target_id, opts)

    {:ok, caster}
  end
end
