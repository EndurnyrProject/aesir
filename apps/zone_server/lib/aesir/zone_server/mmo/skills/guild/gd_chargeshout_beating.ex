defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdChargeshoutBeating do
  @moduledoc """
  Charge Shout Beating (GD_CHARGESHOUT_BEATING). GvG warp-to-placed-flag. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_018,
    name: :gd_chargeshout_beating,
    display_name: "Charge Shout Beating",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
