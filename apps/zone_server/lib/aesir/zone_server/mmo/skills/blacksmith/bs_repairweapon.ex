defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweapon do
  @moduledoc """
  Weapon Repair (BS_REPAIRWEAPON). Repairs a damaged weapon held by an ally. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 108,
    name: :bs_repairweapon,
    display_name: "Weapon Repair",
    max_level: 1,
    target_type: :target_ally,
    damage_type: :no_damage,
    range: 2,
    cast_time: [2_500],
    fixed_cast_time: [2_500],
    sp_cost: [30]
end
