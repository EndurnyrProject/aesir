defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsHiltbinding do
  @moduledoc """
  Hilt Binding (BS_HILTBINDING). Strengthens a weapon handle for a small attack bonus. Its behaviour is not implemented yet.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 105,
    name: :bs_hiltbinding,
    display_name: "Hilt Binding",
    max_level: 1,
    target_type: :passive
end
