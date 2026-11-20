defmodule Aesir.ZoneServer.Mmo.Refine.LevelInfo do
  @moduledoc "Bonuses and available cost options for one refine-table level."

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Refine.Chance
  alias Aesir.ZoneServer.Mmo.Refine.RefineDatabase

  @typedoc "The row at the literal YAML refine level, before any caller-specific offset."
  typedstruct do
    field :bonus, integer(), default: 0
    field :randombonus_max, integer(), default: 0
    field :blessing_amount, non_neg_integer(), default: 0
    field :broadcast_success, boolean(), default: false
    field :broadcast_failure, boolean(), default: false
    field :chances, %{RefineDatabase.cost_type() => Chance.t()}, default: %{}
  end
end
