defmodule Aesir.ZoneServer.Npc.Placement do
  @moduledoc """
  A static NPC placement co-located with its script module.

  Declared via `use Aesir.ZoneServer.Npc, spawn: [...]`; the raw map given there
  is normalized into this struct at compile time. `sprite` is the NPC's view
  class (e.g. `58`); `dir` is the facing direction `0..7`.
  """

  use TypedStruct

  typedstruct do
    field :map, String.t(), enforce: true
    field :x, non_neg_integer(), enforce: true
    field :y, non_neg_integer(), enforce: true
    field :dir, non_neg_integer(), default: 0
    field :sprite, non_neg_integer(), enforce: true
    field :name, String.t(), default: ""
  end
end
