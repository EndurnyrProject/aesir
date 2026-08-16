defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdDevelopment do
  @moduledoc """
  Permanent Development (GD_DEVELOPMENT). Castle economy/defense investment passive. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_014,
    name: :gd_development,
    display_name: "Permanent Development",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
