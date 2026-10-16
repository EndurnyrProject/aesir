defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdEmergencycall do
  @moduledoc """
  Urgent Call (GD_EMERGENCYCALL). Master-cast guild recall: every online guild
  member (the caster excluded) is warped next to the master (`Recall`). Works
  in and out of War of Emperium, on GvG ground only.

  Renewal: 5s fixed cast, 300s cooldown. Pre-renewal: 5s variable cast, 1 SP,
  and the cast blocks the guild skills for 300s (`GuildCooldown`). A caster who
  knows Leap (TK_HIGHJUMP) casts it twice as long: the cast time is doubled
  after its DEX and equipment stage, which only the pre-renewal variable cast
  time reaches.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_013,
    name: :gd_emergencycall,
    display_name: "Urgent Call",
    max_level: 1,
    ignore_dex: true,
    ignore_status_cast: true,
    ignore_item_cast: true,
    target_type: :self,
    sp_cost: [renewal: [], pre_renewal: [1]],
    cast_time: [renewal: [], pre_renewal: [5_000]],
    fixed_cast_time: [renewal: [5_000], pre_renewal: []],
    cooldown: [renewal: [300_000], pre_renewal: []],
    damage_splash: true

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skills.Guild.Recall

  @behaviour Active

  @leap 426
  @lope 5_023

  @impl Active
  def validate(caster, _target, _level, _definition), do: Recall.validate_master(caster)

  @impl Active
  def scale_cast_time(caster, _target, _level, time) do
    if PlayerCaster.skill_level(caster, @leap) > 0 or PlayerCaster.skill_level(caster, @lope) >= 3,
      do: time * 2,
      else: time
  end

  @impl Active
  def rearm_cooldowns(caster, level, definition, now),
    do: Recall.rearm_cooldowns(caster, level, definition, now)

  @impl Active
  def cast(caster, :self, _level, _definition) do
    Recall.summon_members(caster, :all)
    {:ok, caster}
  end
end
