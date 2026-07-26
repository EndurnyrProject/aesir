defmodule Aesir.ZoneServer.Mmo.Skills.Novice.NvFirstaid do
  @moduledoc """
  First Aid (NV_FIRSTAID). Restores a flat 5 HP to the caster.

  rAthena: `status->heal(bl, 5, 0, 0)` - a fixed 5 HP heal regardless of level,
  clamped to max HP. The 3 SP cost is charged by the interpreter (`sp_cost`), so
  the cast only mutates HP and returns the updated caster state.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 142,
    name: :nv_firstaid,
    display_name: "First Aid",
    max_level: 1,
    target_type: :self,
    sp_cost: [3],
    quest_skill: true,
    quest_owner_job: :novice

  alias Aesir.ZoneServer.Mmo.Skill.Active

  @heal_amount 5

  @behaviour Active

  @impl Active
  def cast(%{stats: stats} = caster, :self, _level, _definition) do
    current = stats.current_state
    healed = min(stats.derived_stats.max_hp, current.hp + @heal_amount)
    {:ok, %{caster | stats: %{stats | current_state: %{current | hp: healed}}}}
  end
end
