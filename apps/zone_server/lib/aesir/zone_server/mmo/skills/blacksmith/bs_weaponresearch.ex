defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponresearch do
  @moduledoc """
  Weaponry Research (BS_WEAPONRESEARCH). Improves weapon attack and accuracy through weapon knowledge.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 107,
    name: :bs_weaponresearch,
    display_name: "Weaponry Research",
    max_level: 10,
    target_type: :passive
end
