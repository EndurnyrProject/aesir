defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnCavaliermastery do
  @moduledoc """
  Cavalier Mastery (KN_CAVALIERMASTERY). Reduces the attack-speed penalty
  incurred while mounted on a Peco-Peco.

  Purely a marker: it contributes no direct stat callbacks itself. Its
  learned level is read by the riding status effect, which looks it up to
  scale down the mounted ASPD penalty it applies.

  Renewal and pre-renewal agree: each level buys back 10 of the 50 attack-speed points a mount costs, so a level 5 rider fights unmounted-fast.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 64,
    name: :kn_cavaliermastery,
    display_name: "Cavalier Mastery",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
