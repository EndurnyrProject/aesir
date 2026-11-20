defmodule Aesir.ZoneServer.Mmo.Refine.Chance do
  @moduledoc "One refine cost option, with its material resolved to an item id."

  use TypedStruct

  @typedoc "The price, rates and failure penalty for one cost option."
  typedstruct do
    field :rate, non_neg_integer(), default: 0
    field :price, non_neg_integer(), default: 0
    field :material_nameid, integer()
    field :breaking_rate, non_neg_integer(), default: 0
    field :downgrade, non_neg_integer(), default: 0
  end
end
