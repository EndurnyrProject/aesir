defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdGuardup do
  @moduledoc """
  Strengthen Guardians (GD_GUARDUP). Castle passive boosting guardian attack and ASPD. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_003,
    name: :gd_guardup,
    display_name: "Strengthen Guardians",
    max_level: 3,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
