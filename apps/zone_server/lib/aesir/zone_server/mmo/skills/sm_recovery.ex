defmodule Aesir.ZoneServer.Mmo.Skills.SmRecovery do
  @moduledoc """
  Increase HP Recovery (SM_RECOVERY). Boosts the natural HP recovery tick.

  rAthena (renewal, `status_calc_regen`): adds `skill_lv * 5 + skill_lv * max_hp / 500`
  to the per-tick HP regen. Contributes no SP recovery.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 4,
    name: :sm_recovery,
    display_name: "Increase HP Recovery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def regen_contribution(level, %{max_hp: max_hp}) do
    %{skill_hp_regen: level * 5 + div(level * max_hp, 500)}
  end
end
