defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime do
  @moduledoc """
  Contract for mode-specific cast-time computation.
  """

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @callback compute(Definition.t(), pos_integer(), CastTime.stats()) :: CastTime.result()
end
