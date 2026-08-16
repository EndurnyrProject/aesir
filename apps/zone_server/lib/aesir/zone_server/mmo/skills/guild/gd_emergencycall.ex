defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdEmergencycall do
  @moduledoc """
  Urgent Call (GD_EMERGENCYCALL). Master-cast guild recall: every online
  guild member (the caster excluded) is warped to a walkable cell ringed
  around the master. 5s fixed cast; guild cooldown 300s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_013,
    name: :gd_emergencycall,
    display_name: "Urgent Call",
    max_level: 1,
    target_type: :self,
    fixed_cast_time: [5_000],
    cooldown: [300_000]

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.Recall

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: Recall.validate_master(caster)

  @impl Active
  def cast(caster, :self, _level, _definition) do
    Recall.summon_members(caster, :all)
    {:ok, caster}
  end
end
