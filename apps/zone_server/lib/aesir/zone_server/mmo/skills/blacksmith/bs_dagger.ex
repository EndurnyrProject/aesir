defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsDagger do
  @moduledoc """
  Smith Dagger (BS_DAGGER). Forges daggers from prepared materials.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 98,
    name: :bs_dagger,
    display_name: "Smith Dagger",
    max_level: 3,
    target_type: :self
end
