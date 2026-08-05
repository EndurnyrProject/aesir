defmodule Aesir.ZoneServer.Mmo.Skill.RequirementTest do
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.Skill.Requirement

  test "exposes the closed requirement vocabulary" do
    requirements = [
      :player_state,
      :inventory,
      :party,
      :client_dialog,
      :equipment,
      :zeny,
      :spirit_spheres,
      :partner,
      :homunculus_state
    ]

    assert Requirement.all() == requirements
    assert Enum.all?(requirements, &Requirement.valid?/1)
    refute Requirement.valid?(:inventroy)
  end
end
