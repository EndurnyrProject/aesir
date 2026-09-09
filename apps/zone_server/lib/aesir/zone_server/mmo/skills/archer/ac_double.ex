defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcDouble do
  @moduledoc """
  Double Strafe (AC_DOUBLE). Two ranged bow hits on a single enemy, fired from
  nine cells away and consuming one arrow for the pair. Neither hit can crit,
  and the arrow's element carries the damage exactly as an ordinary bow shot
  does. Vulture's Eye widens the shot: a player adds that skill's learned level
  to the nine cells.

  Renewal: each of the two hits lands at `90 + 10` percent of the attack per
  level, so a level 1 cast is two 100 percent hits and a level 10 cast two 190
  percent hits. The caster is locked out of acting for a tenth of a second
  after the cast.

  Pre-renewal: the same two hits and the same per-level ratio; the only
  difference is that the cast carries no after-cast delay at all, so the skill
  chains straight into the next action.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 46,
    name: :ac_double,
    requires: [],
    display_name: "Double Strafe",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    vulture_range: true,
    hit_count: 2,
    requires_ammo: true,
    require_weapon: [:bow],
    sp_cost: List.duplicate(12, 10),
    after_cast_delay: [renewal: List.duplicate(100, 10), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active

  @behaviour Active

  @doc """
  The percentage of the attack each of the two hits deals at `level`.

  Identical in both modes.
  """
  @spec skill_ratio(pos_integer()) :: pos_integer()
  def skill_ratio(level), do: 90 + 10 * level

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(level),
      hit_count: 2,
      skip_crit: true,
      skip_range: true
    ]

    case Combat.execute_skill_attack(caster, target_id, opts) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end
end
