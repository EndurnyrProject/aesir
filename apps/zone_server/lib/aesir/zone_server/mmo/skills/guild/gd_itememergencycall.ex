defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdItememergencycall do
  @moduledoc """
  Item Emergency Call (GD_ITEMEMERGENCYCALL). Item-granted variant of Urgent
  Call - not in the learnable tree; the granting item consumes itself and
  casts through the item entry point. Recalls at most 7/12/20 members by
  level. 5s fixed cast; guild cooldown 300s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_015,
    name: :gd_itememergencycall,
    display_name: "Item Emergency Call",
    max_level: 3,
    target_type: :self,
    fixed_cast_time: List.duplicate(5_000, 3),
    cooldown: List.duplicate(300_000, 3)

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Guild.Recall

  @behaviour Active

  @impl Active
  def validate(caster, _target, _level, _definition), do: Recall.validate_master(caster)

  @impl Active
  def cast(caster, :self, level, _definition) do
    Recall.summon_members(caster, max_calls(level))
    {:ok, caster}
  end

  defp max_calls(1), do: 7
  defp max_calls(2), do: 12
  defp max_calls(level) when level >= 3, do: 20
end
