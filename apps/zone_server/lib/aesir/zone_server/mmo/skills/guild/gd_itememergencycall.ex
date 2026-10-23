defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdItememergencycall do
  @moduledoc """
  Item Emergency Call (GD_ITEMEMERGENCYCALL). The Emergency Scroll variant of
  Urgent Call, not in the learnable tree: recalls at most 7/12/20 members by
  level (`Recall`), on GvG ground only.

  Renewal: 5s fixed cast, 300s cooldown. Pre-renewal: no cast time, and the
  cast blocks the guild skills (not itself) for 300s (`GuildCooldown`).
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_015,
    name: :gd_itememergencycall,
    display_name: "Item Emergency Call",
    max_level: 3,
    target_type: :self,
    fixed_cast_time: [renewal: List.duplicate(5_000, 3), pre_renewal: []],
    cooldown: [renewal: List.duplicate(300_000, 3), pre_renewal: []],
    damage_splash: true,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.Recall

  @behaviour Active

  @impl Active
  def begin_attempt(caster, _target, _level, _definition) do
    with :ok <- Recall.validate_master(caster), do: {:ok, caster}
  end

  @impl Active
  def rearm_cooldowns(caster, level, definition, now),
    do: Recall.rearm_cooldowns(caster, level, definition, now)

  @impl Active
  def cast(caster, :self, level, _definition) do
    Recall.summon_members(caster, max_calls(level))
    {:ok, caster}
  end

  defp max_calls(1), do: 7
  defp max_calls(2), do: 12
  defp max_calls(level) when level >= 3, do: 20
end
