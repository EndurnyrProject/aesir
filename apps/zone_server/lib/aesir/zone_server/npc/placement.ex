defmodule Aesir.ZoneServer.Npc.Placement do
  @moduledoc """
  A static NPC placement co-located with its script module.

  Declared via `use Aesir.ZoneServer.Npc, spawn: [...]`; the raw map given there
  is normalized into this struct at compile time. `sprite` is the NPC's view
  class (e.g. `58`); `dir` is the facing direction `0..7`. A negative `sprite`
  marks an invisible event NPC (a touch-trigger area or controller): it is
  registered, occupies its cell and fires its touch area, but it has no client
  view and cannot be clicked. `unique_name` is the
  name used for `donpcevent`-style targeting; the normalizer falls back to
  `name` when not declared, so this struct carries whatever it is given.
  `trigger` is the touch-area half-extents `{xs, ys}` around the placement's
  cell, or `nil` when the NPC has no touch area. `scope` determines the game
  mode in which the placement participates.
  """

  alias Aesir.ZoneServer.Npc.ContentScope

  @enforce_keys [:map, :x, :y, :sprite]
  defstruct map: nil,
            x: nil,
            y: nil,
            dir: 0,
            sprite: nil,
            name: "",
            unique_name: "",
            trigger: nil,
            scope: :shared

  @type t() :: %__MODULE__{
          map: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          dir: non_neg_integer(),
          sprite: integer(),
          name: String.t(),
          unique_name: String.t(),
          trigger: {non_neg_integer(), non_neg_integer()} | nil,
          scope: ContentScope.t()
        }

  @doc """
  Whether this placement has no client view, i.e. a negative `sprite`.

  Such a placement is a pure event NPC: it still occupies its cell, still
  carries its touch area, and its module's events fire normally; it is simply
  never sent to a client and never accepts a click.
  """
  @spec invisible?(t()) :: boolean()
  def invisible?(%__MODULE__{sprite: sprite}), do: sprite < 0

  @doc """
  Whether the cell `{map, x, y}` lies inside this placement's touch area. A
  placement without a touch area contains nothing.
  """
  @spec touch_area_contains?(t(), String.t(), integer(), integer()) :: boolean()
  def touch_area_contains?(%__MODULE__{trigger: nil}, _map, _x, _y), do: false

  def touch_area_contains?(%__MODULE__{map: map, x: nx, y: ny, trigger: {xs, ys}}, map, x, y),
    do: x in (nx - xs)..(nx + xs) and y in (ny - ys)..(ny + ys)

  def touch_area_contains?(%__MODULE__{}, _map, _x, _y), do: false
end
