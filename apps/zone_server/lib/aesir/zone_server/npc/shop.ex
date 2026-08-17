defmodule Aesir.ZoneServer.Npc.Shop do
  @moduledoc """
  Static NPC shop placement (a buy/sell vendor).

  A shop renders to the client as an NPC unit at `(x, y)`; clicking it opens a
  server-authoritative buy/sell window. Shops are pure data, authored as YAML
  under `priv/db/shops/*.yml` and loaded at boot, mirroring `Npc.Warp`.

  `items` is the buy list: each entry pairs an item `nameid` with an optional
  per-shop buy-price override (`price: nil` falls back to `ItemDefinition.buy`).
  `discount` controls whether skill-based discounts apply to purchases.
  """

  @typedoc "A buy-list entry: an item id with an optional buy-price override."
  @type item :: %{nameid: pos_integer(), price: non_neg_integer() | nil}

  @enforce_keys [:id, :map, :x, :y, :dir, :sprite]
  defstruct id: nil,
            map: nil,
            x: nil,
            y: nil,
            dir: nil,
            sprite: nil,
            name: "",
            items: [],
            discount: true

  @type t() :: %__MODULE__{
          id: String.t(),
          map: String.t(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          dir: non_neg_integer(),
          sprite: non_neg_integer(),
          name: String.t(),
          items: [item()],
          discount: boolean()
        }
end

defmodule Aesir.ZoneServer.Npc.Shop.Registry do
  @moduledoc """
  Lookup helpers over the per-map shop index held by `Npc.Shops`.

  `entity_id/1` is a pure function of the placement cell and shop `id`, mirroring
  `Npc.Registry.entity_id/1`'s `{map, x, y, unique_name}` keying; the remaining
  helpers (`fetch/1`, `for_map/1`, `by_cell/3`, `entries/0`) read the
  `:persistent_term` index owned by `Npc.Shops`, the way `Npc.Registry`'s
  `module_for_unit/1` and `module_at/3` read its own registry.
  """

  alias Aesir.ZoneServer.Npc.Shop
  alias Aesir.ZoneServer.Npc.Shops

  # Reserved high gid range for static shop entities. `:erlang.phash2/1` yields
  # 0..2^27-1, so shop gids span `0x4800_0000..0x4FFF_FFFF`, within `uint32`
  # (the `UnitSpawn.gid` width) and disjoint from warp entities (`0x4000_0000`
  # base, range `0x4000_0000..0x47FF_FFFF`) and NPC entities (`0x5000_0000`).
  @shop_entity_id_base 0x4800_0000

  @doc """
  Derives a stable synthetic `gid` for a shop placement.

  A pure function of `{map, x, y, id}` in the reserved shop range: the same
  placement always resolves to the same gid across runs and nodes, with no
  process or registry write. Including `id` — the shop's unique identity, e.g.
  `"Tool Dealer#yuno"` — means two shops legitimately sharing a cell (rAthena's
  base vendor plus its `#Extended_*` twin) each get their own gid and stay
  independently clickable rather than collapsing onto one.
  """
  @spec entity_id(Shop.t()) :: non_neg_integer()
  def entity_id(%Shop{} = shop) do
    @shop_entity_id_base + :erlang.phash2({shop.map, shop.x, shop.y, shop.id})
  end

  @doc """
  Returns every loaded shop as a flat list.
  """
  @spec entries() :: [Shop.t()]
  def entries, do: Shops.all() |> Map.values() |> List.flatten()

  @doc """
  Returns the shop list for a given map.
  """
  @spec for_map(String.t()) :: {:ok, [Shop.t()]} | :error
  def for_map(map_name), do: Shops.for_map(map_name)

  @doc """
  Resolves a shop's synthetic gid back to its `Shop`, for click routing.
  """
  @spec fetch(non_neg_integer()) :: {:ok, Shop.t()} | :error
  def fetch(gid) do
    case Enum.find(entries(), &(entity_id(&1) == gid)) do
      nil -> :error
      %Shop{} = shop -> {:ok, shop}
    end
  end

  @doc """
  Returns the shop placed at `{map, x, y}`, or `:error` if none.
  """
  @spec by_cell(String.t(), non_neg_integer(), non_neg_integer()) :: {:ok, Shop.t()} | :error
  def by_cell(map_name, x, y) do
    with {:ok, shops} <- Shops.for_map(map_name),
         %Shop{} = shop <- Enum.find(shops, &(&1.x == x and &1.y == y)) do
      {:ok, shop}
    else
      _ -> :error
    end
  end
end
