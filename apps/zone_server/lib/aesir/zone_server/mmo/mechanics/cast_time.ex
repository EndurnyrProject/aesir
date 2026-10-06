defmodule Aesir.ZoneServer.Mmo.Mechanics.CastTime do
  @moduledoc """
  Contract for mode-specific cast-time computation.
  """

  alias Aesir.ZoneServer.Mmo.Skill.CastTime
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @callback early(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.stage_result()
  @callback late(Definition.t(), pos_integer(), CastTime.inputs(), number()) ::
              CastTime.resolved()
  @callback compute(Definition.t(), pos_integer(), CastTime.inputs()) :: CastTime.result()
end
