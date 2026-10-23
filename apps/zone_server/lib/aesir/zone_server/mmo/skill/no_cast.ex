defmodule Aesir.ZoneServer.Mmo.Skill.NoCast do
  @moduledoc """
  The skill map restrictions of the active mode (`skill_nocast.yml`).

  Each skill carries a mask; `refused?/2` refuses it on a map the mask names:
  bit 1 anywhere but versus ground (`MapFlags.vs2?/1`), bit 2 on PvP maps,
  bit 4 on GvG maps and castles outside War of Emperium TE, bit 8 on
  battlegrounds, bit 16 on War of Emperium TE maps and castles, and any
  restricted-zone bit the map carries. Rows of the import overlay add their
  bits to the shipped mask. Loaded on first use; `reload/0` re-reads it.
  """

  import Bitwise

  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.DataLoader

  @doc "Reloads the masks from the active mode's data."
  @spec reload() :: :ok
  def reload do
    :persistent_term.put(__MODULE__, load())
    :ok
  end

  @doc "The skill's restriction mask, `0` when it has none."
  @spec mask(integer()) :: non_neg_integer()
  def mask(skill_id), do: Map.get(index(), skill_id, 0)

  @doc "Whether the skill's mask refuses it on `map_name`."
  @spec refused?(integer(), String.t()) :: boolean()
  def refused?(skill_id, map_name) do
    case mask(skill_id) do
      0 -> false
      mask -> Enum.any?(conditions(mask, map_name), & &1.())
    end
  end

  defp conditions(mask, map_name) do
    [
      fn -> set?(mask, 1) and not MapFlags.vs2?(map_name) end,
      fn -> set?(mask, 2) and MapFlags.get(map_name, :pvp) end,
      fn -> set?(mask, 4) and MapFlags.gvg2_no_te?(map_name) end,
      fn -> set?(mask, 8) and MapFlags.get(map_name, :battleground) end,
      fn -> set?(mask, 16) and MapFlags.gvg2_te?(map_name) end,
      fn -> band(mask, MapFlags.zone(map_name)) != 0 end
    ]
  end

  defp set?(mask, bit), do: band(mask, bit) != 0

  defp index do
    case :persistent_term.get(__MODULE__, nil) do
      nil ->
        loaded = load()
        :persistent_term.put(__MODULE__, loaded)
        loaded

      loaded ->
        loaded
    end
  end

  defp load do
    DataLoader.load("skill_nocast.yml", "skill_nocast_v1.etf", fn sources ->
      sources
      |> Enum.flat_map(&(DataLoader.parse_file(&1) || []))
      |> Enum.reduce(%{}, fn %{"id" => id, "flags" => flags}, masks ->
        Map.update(masks, id, flags, &bor(&1, flags))
      end)
    end)
  end
end
