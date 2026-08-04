defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifBrain do
  @moduledoc """
  Brain Surgery (HLIF_BRAIN). Its passive resource, regeneration, and Healing
  Touch effects are derived by the Homunculus stats subsystem.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_003,
    name: :hlif_brain,
    display_name: "Brain Surgery",
    max_level: 5,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive
end
