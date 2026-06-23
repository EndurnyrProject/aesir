defmodule Aesir.ZoneServer.Npc.Warp do
  @moduledoc """
  Static NPC warp placement (map teleporter).

  A warp renders to the client as an NPC unit and fires when a player steps
  into (or spawns onto) its `xs`/`ys` trigger area — a `(2*xs+1) x (2*ys+1)`
  square centred on `(x, y)`. `xs`/`ys` are half-width/half-height radii,
  matching the rAthena convention also used by `Mmo.MobManagement.MobSpawn`.
  """

  use TypedStruct

  typedstruct do
    field :id, String.t(), enforce: true
    field :map, String.t(), enforce: true
    field :to_map, String.t(), enforce: true
    field :x, non_neg_integer(), enforce: true
    field :y, non_neg_integer(), enforce: true
    field :xs, non_neg_integer(), default: 0
    field :ys, non_neg_integer(), default: 0
    field :to_x, non_neg_integer(), enforce: true
    field :to_y, non_neg_integer(), enforce: true
    field :sprite, non_neg_integer(), default: 0
    field :name, String.t(), default: ""
  end
end

defmodule Aesir.ZoneServer.Npc.Warp.Registry do
  @moduledoc """
  Pure-function predicates over lists of `Warp.t()`.

  State-free: callers pass the warp list explicitly (e.g. the per-map list
  returned by `Npc.Warps.for_map/1`). `hit?/3` answers "does this cell fall
  inside any warp's trigger area?".
  """

  alias Aesir.ZoneServer.Npc.Warp

  @doc """
  Returns `true` when `(x, y)` falls inside `warp`'s `xs`/`ys` trigger area.
  """
  @spec cell_in_area?(Warp.t(), integer(), integer()) :: boolean()
  def cell_in_area?(%Warp{} = warp, x, y) do
    x in (warp.x - warp.xs)..(warp.x + warp.xs) and
      y in (warp.y - warp.ys)..(warp.y + warp.ys)
  end

  @doc """
  Returns the first `Warp` whose area contains `(x, y)`, or `nil` if none do.
  """
  @spec hit?([Warp.t()], integer(), integer()) :: Warp.t() | nil
  def hit?(warps, x, y) when is_list(warps) do
    Enum.find(warps, &cell_in_area?(&1, x, y))
  end
end
