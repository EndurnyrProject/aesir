defmodule Aesir.ZoneServer.Npc.Warps.Importer do
  @moduledoc """
  Parses rAthena warp script lines into our warp YAML maps.

  A rAthena warp line is four whitespace-separated columns:

      <map>,<x>,<y>,<facing>	warp	<name>	<spanx>,<spany>,<to_map>,<to_x>,<to_y>

  `warp2` (also fires for hidden players) and the `warp(<STATE>)` /
  `warp2(<STATE>)` state variants all map to the same placement; `facing` is
  ignored (irrelevant in rAthena, always `0`). `spanx`/`spany` are
  half-width/half-height radii, matching our `xs`/`ys`. `sprite` is the warp
  portal class `45`; `name` is left blank, faithful to the invisible portal.

  Pure functions - the boot-safety check against `MapCache` lives in the
  `Mix.Tasks.Aesir.Import.Warps` task, not here.
  """

  @warp_sprite 45

  @type warp_map :: %{String.t() => String.t() | non_neg_integer() | map()}

  @doc """
  Parses one line of a rAthena warp script.

    * `{:ok, warp_map}` - a valid warp placement, keyed as our YAML schema
    * `:skip` - a blank line, `//` comment, non-warp NPC line, or non-UTF-8 line
    * `{:error, reason}` - a `warp`/`warp2` line that fails to parse
  """
  @spec parse_line(String.t()) :: {:ok, warp_map()} | :skip | {:error, term()}
  def parse_line(line) when is_binary(line) do
    if String.valid?(line) do
      classify(String.trim(line))
    else
      :skip
    end
  end

  @spec classify(String.t()) :: {:ok, warp_map()} | :skip | {:error, term()}
  defp classify(""), do: :skip
  defp classify("//" <> _), do: :skip

  defp classify(line) do
    case String.split(line, ~r/\s+/, trim: true) do
      [position, type, name, params] -> parse_warp(type, position, name, params)
      _ -> :skip
    end
  end

  @spec parse_warp(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, warp_map()} | :skip | {:error, term()}
  defp parse_warp(type, position, name, params) do
    if warp_type?(type) do
      build(position, name, params)
    else
      :skip
    end
  end

  @spec warp_type?(String.t()) :: boolean()
  defp warp_type?(type), do: Regex.match?(~r/^warp2?(\([A-Za-z]+\))?$/, type)

  @spec build(String.t(), String.t(), String.t()) :: {:ok, warp_map()} | :skip | {:error, term()}
  defp build(position, name, params) do
    case String.split(position, ",") do
      [map, x, y, _facing] -> to_warp(map, name, x, y, position, params)
      _ -> :skip
    end
  end

  @spec to_warp(String.t(), String.t(), String.t(), String.t(), String.t(), String.t()) ::
          {:ok, warp_map()} | {:error, term()}
  defp to_warp(map, name, x, y, position, params) do
    with [xs, ys, to_map, to_x, to_y] <- String.split(params, ","),
         {:ok, x} <- to_int(x),
         {:ok, y} <- to_int(y),
         {:ok, xs} <- to_int(xs),
         {:ok, ys} <- to_int(ys),
         {:ok, to_x} <- to_int(to_x),
         {:ok, to_y} <- to_int(to_y) do
      {:ok,
       %{
         "id" => name,
         "map" => map,
         "x" => x,
         "y" => y,
         "xs" => xs,
         "ys" => ys,
         "sprite" => @warp_sprite,
         "name" => "",
         "to" => %{"map" => to_map, "x" => to_x, "y" => to_y}
       }}
    else
      _ -> {:error, {:malformed, position, params}}
    end
  end

  @spec to_int(String.t()) :: {:ok, integer()} | :error
  defp to_int(str) do
    case Integer.parse(str) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end
end
