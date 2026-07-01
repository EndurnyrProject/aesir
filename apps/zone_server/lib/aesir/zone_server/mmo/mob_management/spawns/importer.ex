defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.Importer do
  @moduledoc """
  Parses rAthena mob-spawn script lines into our spawn YAML maps.

  A rAthena spawn line is four tab-separated columns:

      <map>,<x>[,<y>[,<xs>,<ys>]]	monster	<Name>	<mobId>,<amount>,<delay1>[,<delay2>,<event>,<size>,<ai>]

  The location field is three parts (`map,x,y`, implying `xs=ys=0`) or five
  parts (`map,x,y,xs,ys`); `x,y = 0,0` means "anywhere on the map". The mob CSV
  maps `mobId -> mob`, `amount`, and `delay1 -> respawn_time` (ms); the trailing
  `delay2,event,size,ai` fields are not modeled and dropped. `Name` is
  decorative - we key by numeric id.

  Only `monster` lines are imported; `boss_monster`, comments, blanks, and any
  other NPC line are skipped. Pure functions - the boot-safety checks against
  `MapCache`/`Mobs` live in the `Mix.Tasks.Aesir.Import.Spawns` task, not here.
  """

  @type spawn_map :: %{String.t() => String.t() | [map()]}

  @doc """
  Parses one line of a rAthena mob-spawn script.

    * `{:ok, spawn_map}` - a valid `monster` spawn, keyed as our YAML schema
    * `:skip` - a blank line, `//` comment, `boss_monster`, non-`monster`, or
      non-UTF-8 line
    * `{:error, reason}` - a `monster` line that fails to parse
  """
  @spec parse_line(String.t()) :: {:ok, spawn_map()} | :skip | {:error, term()}
  def parse_line(line) when is_binary(line) do
    if String.valid?(line) do
      classify(String.trim(line))
    else
      :skip
    end
  end

  @spec classify(String.t()) :: {:ok, spawn_map()} | :skip | {:error, term()}
  defp classify(""), do: :skip
  defp classify("//" <> _), do: :skip

  defp classify(line) do
    case String.split(line, "\t", trim: true) do
      [location, "monster", _name, csv] -> build(location, csv)
      _ -> :skip
    end
  end

  @spec build(String.t(), String.t()) :: {:ok, spawn_map()} | {:error, term()}
  defp build(location, csv) do
    with {:ok, map, x, y, xs, ys} <- parse_location(location),
         {:ok, mob, amount, respawn_time} <- parse_csv(csv) do
      {:ok,
       %{
         "map" => map,
         "spawns" => [
           %{
             "mob" => mob,
             "amount" => amount,
             "respawn_time" => respawn_time,
             "area" => %{"x" => x, "y" => y, "xs" => xs, "ys" => ys}
           }
         ]
       }}
    else
      _ -> {:error, {:malformed, location, csv}}
    end
  end

  @spec parse_location(String.t()) ::
          {:ok, String.t(), integer(), integer(), integer(), integer()} | :error
  defp parse_location(location) do
    case String.split(location, ",") do
      [map, x, y] ->
        with {:ok, x} <- to_int(x), {:ok, y} <- to_int(y), do: {:ok, map, x, y, 0, 0}

      [map, x, y, xs, ys] ->
        with {:ok, x} <- to_int(x),
             {:ok, y} <- to_int(y),
             {:ok, xs} <- to_int(xs),
             {:ok, ys} <- to_int(ys),
             do: {:ok, map, x, y, xs, ys}

      _ ->
        :error
    end
  end

  @spec parse_csv(String.t()) :: {:ok, integer(), integer(), integer()} | :error
  defp parse_csv(csv) do
    case String.split(csv, ",") do
      [mob, amount, respawn_time | _rest] ->
        with {:ok, mob} <- to_int(mob),
             {:ok, amount} <- to_int(amount),
             {:ok, respawn_time} <- to_int(respawn_time),
             do: {:ok, mob, amount, respawn_time}

      _ ->
        :error
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
