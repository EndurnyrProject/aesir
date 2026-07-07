defmodule Aesir.ZoneServer.Mmo.Skills.TfMiss do
  @moduledoc """
  Improve Dodge (TF_MISS). Adds flat FLEE while learned.

  rAthena: +3 FLEE per skill level (first-job Thief branch).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 49,
    name: :tf_miss,
    display_name: "Improve Dodge",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def flee_bonus(level, _ctx), do: 3 * level
end
