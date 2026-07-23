defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnPierce do
  @moduledoc """
  Pierce (KN_PIERCE). Single-target spear thrust whose number of hits scales
  with the target's size and whose own accuracy is boosted above the caster's
  base hit rate.

  Renewal: 100% + 10% per level weapon damage per hit, no crit. The hit count
  is 1 against a small target, 2 against medium, 3 against large - each hit
  rolls its own hit/flee check and deals its own damage, mirroring
  `AC_DOUBLE`'s multi-hit shape. The cast itself carries a +5% per level
  relative bonus to the already-clamped hit rate for that attack only (e.g. a
  30% base rate becomes 45% at level 10 - `30 * 150 / 100` - not a flat
  addition to the `hit` stat before the `80 + hit - flee` formula).

  Players must wield a one-handed or two-handed spear to cast it; mobs bypass
  the weapon check entirely since they have no equipment.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 56,
    name: :kn_pierce,
    display_name: "Pierce",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    range: -1,
    sp_cost: List.duplicate(7, 10)

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats

  @behaviour Active

  @spear_weapon_types [:one_handed_spear, :two_handed_spear]

  @impl Active
  def validate(%PlayerState{stats: %{equipment: equipment}}, _target, _level, _definition) do
    if Stats.weapon_type(equipment) in @spear_weapon_types do
      :ok
    else
      {:error, :requires_spear}
    end
  end

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{size: size}} <- Combat.resolve_combatant(target_id) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 100 + 10 * level,
        hit_count: hits_for_size(size),
        hit_rate_bonus_pct: 5 * level,
        skip_crit: true
      ]

      case Combat.execute_skill_attack(caster, target_id, opts) do
        :ok -> {:ok, caster}
        {:error, _reason} = error -> error
      end
    end
  end

  @spec hits_for_size(:small | :medium | :large) :: pos_integer()
  defp hits_for_size(:small), do: 1
  defp hits_for_size(:medium), do: 2
  defp hits_for_size(:large), do: 3
end
