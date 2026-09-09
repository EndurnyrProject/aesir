defmodule Aesir.ZoneServer.Mmo.Skills.Archer.AcOwl do
  @moduledoc """
  Owl's Eye (AC_OWL). A passive granting one point of DEX per skill level, up
  to ten at master level.

  The bonus is identical in both modes and is a base-stat bonus, not an
  equipment one: it is added before gear and cards, so it counts towards
  everything DEX drives - accuracy, ranged attack, cast time - and it is the
  base Improve Concentration takes its percentage of.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 43,
    name: :ac_owl,
    display_name: "Owl's Eye",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def dex_bonus(level, _ctx), do: level
end
