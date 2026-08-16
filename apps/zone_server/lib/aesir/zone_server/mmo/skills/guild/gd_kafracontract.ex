defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdKafracontract do
  @moduledoc """
  Kafra Contract (GD_KAFRACONTRACT). Castle-steward passive enabling owner-only Kafra services. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_001,
    name: :gd_kafracontract,
    display_name: "Kafra Contract",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
