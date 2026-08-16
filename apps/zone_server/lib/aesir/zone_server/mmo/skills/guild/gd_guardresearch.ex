defmodule Aesir.ZoneServer.Mmo.Skills.Guild.GdGuardresearch do
  @moduledoc """
  Guardian Research (GD_GUARDRESEARCH). Castle passive enabling guardian deployment. Inert until WoE lands.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 10_002,
    name: :gd_guardresearch,
    display_name: "Guardian Research",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
