defmodule Aesir.ZoneServer.Mmo.Skills.Mage.MgSrecovery do
  @moduledoc """
  Increase SP Recovery (MG_SRECOVERY). Boosts the natural SP recovery tick.

  Adds `3 * level + level * max SP / 500` to the per-tick SP regeneration and
  contributes nothing to HP recovery. It also makes SP-restoring consumables 10
  percent more effective per learned level, applied by the item recovery path
  alongside INT and Potion Research.

  Renewal and pre-renewal are identical here: neither the regeneration term nor
  the consumable bonus is mode-gated.
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
