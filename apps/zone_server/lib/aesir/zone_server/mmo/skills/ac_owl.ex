defmodule Aesir.ZoneServer.Mmo.Skills.AcOwl do
  @moduledoc """
  Owl's Eye (AC_OWL). Grants +1 DEX per skill level (max +10).

  rAthena: AC_OWL passive — flat DEX bonus equal to skill level.
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
