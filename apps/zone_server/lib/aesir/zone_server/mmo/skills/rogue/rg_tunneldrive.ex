defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive do
  use Aesir.ZoneServer.Mmo.Skill,
    id: 213,
    name: :rg_tunneldrive,
    display_name: "Stalk",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def hidden_move_speed(level, _ctx), do: 120 - 6 * level
end
