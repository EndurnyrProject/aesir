defmodule Aesir.ZoneServer.Mmo.Skills.Hunter.HtBeastbane do
  @moduledoc """
  Beast Bane (HT_BEASTBANE).

  Passive that adds flat physical ATK against Brute and Insect targets. The
  combatant's learned level drives the physical weapon damage pipeline.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 126,
    name: :ht_beastbane,
    display_name: "Beast Bane",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
