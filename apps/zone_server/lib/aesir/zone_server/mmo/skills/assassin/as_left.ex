defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsLeft do
  @moduledoc "Lefthand Mastery (AS_LEFT). Raises left-hand dual-wield damage."
  use Aesir.ZoneServer.Mmo.Skill,
    id: 133,
    name: :as_left,
    display_name: "Lefthand Mastery",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def left_hand_damage_rate(level, _ctx), do: 30 + 10 * level
end
