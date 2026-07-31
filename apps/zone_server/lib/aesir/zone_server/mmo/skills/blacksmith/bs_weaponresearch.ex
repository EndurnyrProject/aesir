defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponresearch do
  @moduledoc """
  Weaponry Research (BS_WEAPONRESEARCH). Improves weapon attack and accuracy through weapon knowledge.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 107,
    name: :bs_weaponresearch,
    display_name: "Weaponry Research",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, _ctx), do: 2 * level

  @impl Passive
  def hit_rate_bonus_pct(level, _ctx), do: 2 * level
end
