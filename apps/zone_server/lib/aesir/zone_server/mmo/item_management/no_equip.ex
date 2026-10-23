defmodule Aesir.ZoneServer.Mmo.ItemManagement.NoEquip do
  @moduledoc """
  Map-type item restrictions: which items have no effect on which maps.

  Each item's restriction mask comes from the active mode's
  `item_noequip.yml`: bit 1 normal maps, 2 PvP, 4 GvG, 8 battlegrounds,
  16 War of Emperium: Training Edge castles, and the higher bits the
  restricted zones a map's `restricted <n>` mapflags give it
  (`MapFlags.zone/1`). A restricted equipment's own script, a restricted
  card's script and a restricted equipment's random option scripts do not run
  on such a map, and a restricted usable item cannot be used there; the item
  can still be worn, as no player group may equip restricted items unchecked
  and restricted equipment is not refused or taken off.

  The masks are cached in `:persistent_term`; `reload/0` rebuilds them.
  """

  import Bitwise

  alias Aesir.ZoneServer.Db.Source
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.DataLoader

  @pt_key __MODULE__

  @versus [:pvp, :gvg_dungeon, :gvg, :gvg_castle, :gvg_te, :gvg_te_castle, :battleground]

  @doc "Returns the item's restriction mask, 0 for an unrestricted item."
  @spec flag(integer()) :: non_neg_integer()
  def flag(item_id), do: Map.get(masks(), item_id, 0)

  @doc """
  Whether `item_id` is restricted on `map_name`. A `nil` map (no map context)
  restricts nothing.
  """
  @spec restricted?(integer(), String.t() | nil) :: boolean()
  def restricted?(_item_id, nil), do: false

  def restricted?(item_id, map_name) do
    case flag(item_id) do
      0 -> false
      mask -> mask_restricted?(mask, map_name)
    end
  end

  @doc "Whether a restriction mask restricts an item on `map_name`."
  @spec mask_restricted?(non_neg_integer(), String.t()) :: boolean()
  def mask_restricted?(mask, map_name) do
    flag? = &MapFlags.get(map_name, &1)

    Enum.any?([1, 2, 4, 8, 16], &(set?(mask, &1) and restricts?(&1, flag?))) or
      band(mask, MapFlags.zone(map_name)) != 0
  end

  # The maps each map-type bit restricts on: 1 a normal map (no versus flag),
  # 2 PvP, 4 GvG or a castle, 8 a battleground, 16 a Training Edge GvG map or
  # castle.
  defp restricts?(1, flag?), do: not Enum.any?(@versus, flag?)
  defp restricts?(2, flag?), do: flag?.(:pvp)
  defp restricts?(4, flag?), do: flag?.(:gvg) or flag?.(:gvg_castle)
  defp restricts?(8, flag?), do: flag?.(:battleground)
  defp restricts?(16, flag?), do: flag?.(:gvg_te) or flag?.(:gvg_te_castle)

  defp set?(mask, bit), do: band(mask, bit) != 0

  @doc "Rebuilds the cached masks after editing the data files in a running session."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(@pt_key, load())
    :ok
  end

  defp masks do
    case :persistent_term.get(@pt_key, nil) do
      nil ->
        built = load()
        :persistent_term.put(@pt_key, built)
        built

      built ->
        built
    end
  end

  defp load do
    "item_noequip.yml"
    |> Source.sources()
    |> Enum.flat_map(&(YamlElixir.read_from_file!(&1) || []))
    |> DataLoader.merge_by_key(& &1["item"])
    |> Map.new(fn %{"item" => id, "flag" => flag} -> {id, flag} end)
  end
end
