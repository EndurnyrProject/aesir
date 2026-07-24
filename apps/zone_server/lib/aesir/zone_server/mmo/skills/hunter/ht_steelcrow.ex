defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtSteelcrow do
  @moduledoc """
  Steel Crow (HT_STEELCROW).

  Passive damage input for Falcon attacks. Learning it does not grant direct
  stat bonuses.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 128,
    name: :ht_steelcrow,
    display_name: "Steel Crow",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
