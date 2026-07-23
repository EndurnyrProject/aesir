defmodule Aesir.ZoneServer.Mmo.Skills.Knight.KnCavaliermastery do
  @moduledoc """
  Cavalier Mastery (KN_CAVALIERMASTERY). Reduces the attack-speed penalty
  incurred while mounted on a Peco-Peco.

  Purely a marker: it contributes no direct stat callbacks itself. Its
  learned level is read by the riding status effect, which looks it up to
  scale down the mounted ASPD penalty it applies.
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
