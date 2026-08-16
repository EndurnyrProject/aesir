defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdChargeshoutFlag do
  @moduledoc """
  Charge Shout Flag (GD_CHARGESHOUT_FLAG). GvG guild-flag placement. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_017,
    name: :gd_chargeshout_flag,
    display_name: "Charge Shout Flag",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
