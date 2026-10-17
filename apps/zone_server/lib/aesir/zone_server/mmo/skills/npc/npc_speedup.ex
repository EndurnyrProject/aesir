defmodule Aesir.ZoneServer.Mmo.Skills.Npc.NpcSpeedup do
  @moduledoc """
  NPC Speed Up (NPC_SPEEDUP).

  Monster-only. While at least 700 ms of the monster's trick cast (Random
  Move) are left, it lowers the monster's walk speed by 250 for the rest of its
  life (never below 20); within the last skill interval of that window the
  next skill check waits until 100 ms from now. Otherwise the next skill check
  is synchronized with the trick cast's end, and the trick cast and the escape
  walk's damage immunity end. A walk-time skill check that used this skill
  keeps the monster walking while the trick cast is kept.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 332,
    name: :npc_speedup,
    requires: [],
    display_name: "NPC Speed Up",
    max_level: 10,
    target_type: :self,
    damage_type: :no_damage,
    range: 0,
    is_npc: true,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @behaviour Active

  @skill_interval 1000
  @trick_stop div(@skill_interval * 7, 10)
  @speed_gain 250
  @min_walk_speed 20

  @impl Active
  def cast(_caster, _target, _level, _definition), do: {:error, :mob_only}

  @impl Active
  def mob_cast(%MobState{} = caster, _raw_target, _level, _definition, _row) do
    now = System.system_time(:millisecond)
    trickcasting = caster.trickcasting || 0
    left = trickcasting - now

    if left >= @trick_stop do
      faster = %{caster | walk_speed: max(caster.walk_speed - @speed_gain, @min_walk_speed)}

      if left < @trick_stop + @skill_interval,
        do: {:ok, %{faster | last_skillcheck: now + 100}},
        else: {:ok, faster}
    else
      {:ok, %{caster | last_skillcheck: trickcasting, trickcasting: nil, can_escape: false}}
    end
  end
end
