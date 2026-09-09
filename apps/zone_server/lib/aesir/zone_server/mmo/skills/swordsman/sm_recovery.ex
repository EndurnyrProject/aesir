defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmRecovery do
  @moduledoc """
  Increase HP Recovery (SM_RECOVERY). Feeds the separate skill-driven HP
  regeneration channel.

  Renewal: adds `level * 5 + level * max_hp / 500` HP to every skill-regen tick,
  a channel distinct from the base HP tick and with its own interval. It never
  contributes SP.

  Pre-renewal: the identical amount on the identical channel; nothing about
  this passive's regeneration contribution is era-gated.

  In both modes the skill also raises the potency of HP-restoring consumables
  by 10 percent per level, stacking additively with the potion-research
  passive, VIT and the item heal bonuses.
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
