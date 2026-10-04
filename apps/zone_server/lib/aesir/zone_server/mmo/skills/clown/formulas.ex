defmodule Aesir.ZoneServer.Mmo.Skills.Clown.Formulas do
  @moduledoc "Pure Clown and Gypsy formulas for renewal and pre-renewal."

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Map.MapCache
  alias Aesir.ZoneServer.Map.MapData

  @primary_stats [:str, :agi, :vit, :int, :dex, :luk]

  @doc "Arrow Vulcan's weapon ratio: base-level-scaled in renewal, flat in pre-renewal."
  @spec arrow_vulcan_ratio(pos_integer(), pos_integer()) :: pos_integer()
  def arrow_vulcan_ratio(level, base_level) do
    case GameMode.mode() do
      :renewal -> div((500 + 100 * level) * base_level, 100)
      :pre_renewal -> 200 + 100 * level
    end
  end

  @doc "True when a known map's square box contains no wall cell, in either mode."
  @spec box_wall_free?(String.t(), integer(), integer(), pos_integer()) :: boolean()
  def box_wall_free?(map_name, x, y, radius) do
    case MapCache.get(map_name) do
      {:ok, map} ->
        cells =
          for cx <- (x - radius)..(x + radius), cy <- (y - radius)..(y + radius), do: {cx, cy}

        Enum.all?(cells, fn {cx, cy} -> not MapData.check_cell(map, cx, cy, :chk_wall) end)

      {:error, :not_found} ->
        false
    end
  end

  @doc "Freezes half of each primary base stat, bounded to 0..255 in both modes."
  @spec marionette_halves(map()) :: %{atom() => 0..255}
  def marionette_halves(base_stats) do
    Map.new(@primary_stats, fn stat ->
      {stat, base_stats |> Map.get(stat, 0) |> div(2) |> max(0) |> min(255)}
    end)
  end

  @doc "Caps frozen puppet gains so no total primary stat rises above ninety-nine."
  @spec marionette_gains(%{atom() => 0..255}, map()) :: %{atom() => 0..255}
  def marionette_gains(halves, totals) do
    Map.new(@primary_stats, fn stat ->
      {stat, min(Map.fetch!(halves, stat), max(99 - Map.get(totals, stat, 0), 0))}
    end)
  end
end
