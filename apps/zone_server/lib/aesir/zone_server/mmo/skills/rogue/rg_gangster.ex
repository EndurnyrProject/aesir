defmodule Aesir.ZoneServer.Mmo.Skills.Rogue.RgGangster do
  @moduledoc """
  Both modes let seated Rogues next to each other avoid aggression.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 223,
    name: :rg_gangster,
    display_name: "Slyness",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
