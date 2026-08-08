defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgCompulsion do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 224,
    name: :rg_compulsion,
    display_name: "Haggle",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def shop_discount_pct(level, _ctx), do: 5 + 4 * level
end
