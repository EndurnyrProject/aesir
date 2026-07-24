defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtFalcon do
  @moduledoc """
  Falconry Mastery (HT_FALCON).

  Passive permission to equip a Falcon. Learning it does not equip a Falcon or
  grant stat bonuses.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 127,
    name: :ht_falcon,
    display_name: "Falconry Mastery",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
