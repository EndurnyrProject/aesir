defmodule Aesir.ZoneServer.Npc.Warp do
  @moduledoc """
  Static NPC warp placement (map teleporter).

  A warp renders to the client as an NPC unit and fires when a player steps
  into (or spawns onto) its `xs`/`ys` trigger area — a `(2*xs+1) x (2*ys+1)`
  square centred on `(x, y)`. `xs`/`ys` are half-width/half-height radii,
  matching the rAthena convention also used by `Mmo.MobManagement.MobSpawn`.
  """

  @enforce_keys [:id, :map, :to_map, :x, :y, :to_x, :to_y]
  defstruct id: nil,
            map: nil,
            to_map: nil,
            x: nil,
            y: nil,
            xs: 0,
            ys: 0,
            to_x: nil,
            to_y: nil,
            sprite: 0,
            name: ""

  @type t() :: %__MODULE__{
          id: String.t(),
          map: String.t(),
          to_map: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          xs: non_neg_integer(),
          ys: non_neg_integer(),
          to_x: non_neg_integer(),
          to_y: non_neg_integer(),
          sprite: non_neg_integer(),
          name: String.t()
        }
end

defmodule Aesir.ZoneServer.Npc.Warp.Registry do
  @moduledoc """
  Pure-function predicates over lists of `Warp.t()`.

  State-free: callers pass the warp list explicitly (e.g. the per-map list
  returned by `Npc.Warps.for_map/1`). `hit?/3` answers "does this cell fall
  inside any warp's trigger area?".
  """

  alias Aesir.ZoneServer.Npc.Warp

  # Reserved high gid range for static warp entities. Mob `instance_id`s are
  # allocated in 2..1_999_999 (see `Map.Coordinator.generate_mob_instance_id/0`)
  # and player `character_id`s are DB auto-increment PKs starting at 1; this
  # base sits well above both and never collides with either. `:erlang.phash2/1`
  # is platform-independent (stable across runs and nodes) and yields 0..2^27-1,
  # keeping warp gids within `uint32` (the `UnitSpawn.gid` width, aesir.proto:310).
  @warp_entity_id_base 0x4000_0000

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

  @doc """
  Derives a stable synthetic `gid` for a warp placement.

  Warp entities are static (no process, no `UnitRegistry` entry), so the gid is
  a deterministic function of the placement: `@warp_entity_id_base` plus a
  platform-independent `:erlang.phash2` of `{map, x, y}`. The same warp always
  resolves to the same gid across runs and nodes, and the reserved base keeps
  it disjoint from player `character_id`s and mob `instance_id`s.
  """
  @spec entity_id(Warp.t()) :: non_neg_integer()
  def entity_id(%Warp{} = warp) do
    @warp_entity_id_base + :erlang.phash2({warp.map, warp.x, warp.y})
  end
end
