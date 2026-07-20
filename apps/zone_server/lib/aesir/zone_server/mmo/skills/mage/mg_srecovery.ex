defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSrecovery do
  @moduledoc """
  Increase SP Recovery (MG_SRECOVERY). Boosts the natural SP recovery tick.

  rAthena (renewal, `status_calc_regen`): adds `skill_lv * 3 + skill_lv * max_sp / 500`
  to the per-tick SP regen. Contributes no HP recovery.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 9,
    name: :mg_srecovery,
    display_name: "Increase SP Recovery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def regen_contribution(level, %{max_sp: max_sp}) do
    %{skill_sp_regen: level * 3 + div(level * max_sp, 500)}
  end
end
