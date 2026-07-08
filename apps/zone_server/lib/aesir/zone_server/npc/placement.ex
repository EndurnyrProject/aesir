defmodule Aesir.ZoneServer.Npc.Placement do
  @moduledoc """
  A static NPC placement co-located with its script module.

  Declared via `use Aesir.ZoneServer.Npc, spawn: [...]`; the raw map given there
  is normalized into this struct at compile time. `sprite` is the NPC's view
  class (e.g. `58`); `dir` is the facing direction `0..7`. `unique_name` is the
  name used for `donpcevent`-style targeting; `to_placement!/1` falls back
  to `name` when not declared, so this struct carries whatever it is given.
  `trigger` is the touch-area half-extents `{xs, ys}` around the placement's
  cell, or `nil` when the NPC has no touch area.
  """

  use TypedStruct

  typedstruct do
    field :map, String.t(), enforce: true
    field :x, non_neg_integer(), enforce: true
    field :y, non_neg_integer(), enforce: true
    field :dir, non_neg_integer(), default: 0
    field :sprite, non_neg_integer(), enforce: true
    field :name, String.t(), default: ""
    field :unique_name, String.t(), default: ""
    field :trigger, {non_neg_integer(), non_neg_integer()} | nil, default: nil
  end
end
