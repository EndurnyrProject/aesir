defmodule Aesir.ZoneServer.Mmo.Skill.Passives.SmRecovery do
  @moduledoc """
  Increase HP Recovery (SM_RECOVERY). Boosts the natural HP recovery tick.

  rAthena (renewal, `status_calc_regen`): adds `skill_lv * 5 + skill_lv * max_hp / 500`
  to the per-tick HP regen. Contributes no SP recovery.
  """
  use Aesir.ZoneServer.Mmo.Skill.Passive, skill: :sm_recovery

  @impl true
  def regen_contribution(level, %{max_hp: max_hp}) do
    %{hp_regen: level * 5 + div(level * max_hp, 500)}
  end
end
