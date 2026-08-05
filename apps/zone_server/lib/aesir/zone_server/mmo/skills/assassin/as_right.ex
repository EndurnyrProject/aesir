defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsRight do
  @moduledoc "Righthand Mastery (AS_RIGHT). Raises right-hand dual-wield damage."
  use Aesir.ZoneServer.Mmo.Skill,
    id: 132,
    name: :as_right,
    display_name: "Righthand Mastery",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def right_hand_damage_rate(level, _ctx), do: 50 + 10 * level
end
