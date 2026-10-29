defmodule Aesir.ZoneServer.Mmo.Skills.Creator.CrAciddemonstration do
  @moduledoc """
  Acid Demonstration (CR_ACIDDEMONSTRATION).

  Throws a Fire Bottle and an Acid Bottle at an enemy up to 9 cells away, in one
  hit per level that multiplies the calculated damage. After a hit that
  connects, or that a blocking status stopped, on a player who survives it,
  the target's weapon and then its armor each break at the level in percent
  (the ordinary break protections apply). Monsters' equipment never breaks.

  Renewal: a weapon skill with the weapon's element whose ratio is `200 * level`
  plus the caster's INT and the target's VIT, halved against a player; it rolls
  hit and flee and never crits. 50 SP, a 1 s fixed cast, a 1 s delay and a
  0.15 s cooldown. Monsters cast it with their own INT.

  Pre-renewal: a neutral misc attack that never misses, with a base of
  `7 * VIT * INT^2 / (10 * (VIT + INT))` from the target's VIT and the caster's
  INT (0 when both are 0), halved against a player. 30 SP, a 1 s cast and a 1 s
  delay.

  Neutral Barrier, which would make the attack miss, does not exist yet; it
  belongs in the target's damage stage.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 490,
    name: :cr_aciddemonstration,
    requires: [],
    display_name: "Acid Demonstration",
    max_level: 10,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: [renewal: :weapon, pre_renewal: :misc],
    ignore_flee: [renewal: false, pre_renewal: true],
    range: 9,
    hit_count: Enum.to_list(1..10),
    sp_cost: [renewal: List.duplicate(50, 10), pre_renewal: List.duplicate(30, 10)],
    item_cost: [%{id: 7135, amount: 1}, %{id: 7136, amount: 1}],
    cast_time: [renewal: [], pre_renewal: List.duplicate(1_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(1_000, 10), pre_renewal: []],
    after_cast_delay: List.duplicate(1_000, 10),
    cooldown: [renewal: List.duplicate(150, 10), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageInputs
  alias Aesir.ZoneServer.Mmo.Combat.EquipBreak
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    case attack(GameMode.mode(), caster, target_id, level, definition) do
      {:ok, report} ->
        if (report.hit? or report.blocked?) and report.target_survives?,
          do: break_equipment(target_id, level)

        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp attack(:renewal, caster, target_id, level, definition) do
    int = caster_int(caster)

    Combat.execute_skill_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: {:target, &renewal_ratio(level, int, &1)},
      hit_divisions: level,
      skip_crit: true,
      skip_range: true,
      report_hit: true
    )
  end

  defp attack(:pre_renewal, caster, target_id, level, definition) do
    int = caster_int(caster)

    Combat.execute_misc_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      base_damage: {:target, &classic_base(int, &1)},
      element: :neutral,
      hit_divisions: level,
      report_hit: true
    )
  end

  defp renewal_ratio(level, int, %Combatant{} = target),
    do: halved_on_player(200 * level + int + DamageInputs.effective_stat(target, :vit), target)

  defp classic_base(int, %Combatant{} = target) do
    case DamageInputs.effective_stat(target, :vit) do
      vit when vit + int == 0 -> 0
      vit -> halved_on_player(div(7 * vit * int * int, 10 * (vit + int)), target)
    end
  end

  defp halved_on_player(value, %Combatant{unit_type: :player}), do: div(value, 2)
  defp halved_on_player(value, _target), do: value

  defp caster_int(%PlayerState{stats: stats}), do: PlayerStats.get_effective_stat(stats, :int)

  defp caster_int(caster),
    do: DamageInputs.effective_stat(caster.__struct__.to_combatant(caster), :int)

  defp break_equipment(target_id, level) do
    case TargetResolver.resolve(target_id) do
      {:ok, pid, %PlayerState{character_id: id, stats: stats}, :player} ->
        for slot <- [:weapon, :armor],
            {:target, ^slot} <-
              EquipBreak.resolve_slot(100 * level, {:player, id, stats}, slot, []),
            do: PlayerSession.break_equip(pid, slot)

      _not_a_player ->
        :ok
    end
  end
end
