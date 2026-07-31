defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsWeaponperfect do
  @moduledoc """
  Weapon Perfection (BS_WEAPONPERFECT). Temporarily removes weapon size penalties for the caster and nearby allies. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 112,
    name: :bs_weaponperfect,
    display_name: "Weapon Perfection",
    max_level: 5,
    target_type: :self,
    sp_cost: [18, 16, 14, 12, 10],
    duration: [10_000, 20_000, 30_000, 40_000, 50_000],
    status: :sc_weaponperfection
end
