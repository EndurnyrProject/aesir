defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgTunneldrive do
  @moduledoc """
  Both modes move while hidden at 120 minus 6 per level percent of the cell delay.
  """

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
