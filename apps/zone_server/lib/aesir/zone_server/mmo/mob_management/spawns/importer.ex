defmodule Aesir.ZoneServer.Mmo.MobManagement.Spawns.Importer do
  @moduledoc """
  Parses rAthena mob-spawn script lines into our spawn YAML maps.

  A rAthena spawn line is four tab-separated columns:

      <map>,<x>[,<y>[,<xs>,<ys>]]	monster|boss_monster	<Name>	<mobId>,<amount>,<delay1>[,<delay2>,<event>,<size>,<ai>]

  The location field is one part (bare `map`, implying `x=y=xs=ys=0`), three
  parts (`map,x,y`, implying `xs=ys=0`), or five parts (`map,x,y,xs,ys`);
  `x,y = 0,0` means "anywhere on the map". The mob CSV maps `mobId -> mob`,
  `amount`, optional `delay1 -> respawn_time` (ms, defaulting to 0), and
  optional `delay2 -> respawn_variance` (ms, defaulting to 0); the trailing
  `event,size,ai` fields are not modeled and dropped. `Name` is decorative -
  we key by the mob token.

  The `mob` token is kept as-is: an integer id, or a non-numeric rAthena
  constant/aegis name (a `String.t()`) to be resolved against `Mobs` by the Mix
  task. Keeping the token here keeps this module pure.

  Both `monster` and `boss_monster` lines are imported; comments, blanks, and
  any other NPC line are skipped. Pure functions - the boot-safety checks
  against `MapCache`/`Mobs` live in the `Mix.Tasks.Aesir.Import.Spawns` task,
  not here.
  """

  @type spawn_map :: %{String.t() => String.t() | [map()]}

  @doc """
  Parses one line of a rAthena mob-spawn script.

    * `{:ok, spawn_map}` - a valid `monster` or `boss_monster` spawn, keyed as
      our YAML schema. The spawn's `"mob"` is an integer id or a non-numeric
      aegis-name token (`String.t()`) for the Mix task to resolve.
    * `:skip` - a blank line, `//` comment, non-`monster`/`boss_monster`, or
      non-UTF-8 line
    * `{:error, reason}` - a `monster` or `boss_monster` line that fails to parse
  """
  @spec parse_line(String.t()) :: {:ok, spawn_map()} | :skip | {:error, term()}
  def parse_line(line) when is_binary(line) do
    if String.valid?(line) do
      line |> strip_comment() |> String.trim() |> classify()
    else
      :skip
    end
  end

  @spec strip_comment(String.t()) :: String.t()
  defp strip_comment(line), do: line |> String.split("//", parts: 2) |> hd()

  @spec classify(String.t()) :: {:ok, spawn_map()} | :skip | {:error, term()}
  defp classify(""), do: :skip

  defp classify(line) do
    case String.split(line, "\t", trim: true) do
      [location, kind, _name, csv] when kind in ["monster", "boss_monster"] ->
        build(location, csv)

      _ ->
        :skip
    end
  end

  @spec build(String.t(), String.t()) :: {:ok, spawn_map()} | {:error, term()}
  defp build(location, csv) do
    with {:ok, map, x, y, xs, ys} <- parse_location(location),
         {:ok, mob, amount, respawn_time, respawn_variance} <- parse_csv(csv) do
      {:ok,
       %{
         "map" => map,
         "spawns" => [
           %{
             "mob" => mob,
             "amount" => amount,
             "respawn_time" => respawn_time,
             "respawn_variance" => respawn_variance,
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
      [map] ->
        {:ok, map, 0, 0, 0, 0}

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

  @spec parse_csv(String.t()) ::
          {:ok, integer() | String.t(), integer(), integer(), integer()} | :error
  defp parse_csv(csv) do
    case csv |> String.split(",") |> Enum.map(&String.trim/1) do
      [mob, amount] ->
        with {:ok, amount} <- to_int(amount), do: {:ok, mob_token(mob), amount, 0, 0}

      [mob, amount, respawn_time] ->
        with {:ok, amount} <- to_int(amount),
             {:ok, respawn_time} <- to_int(respawn_time),
             do: {:ok, mob_token(mob), amount, respawn_time, 0}

      [mob, amount, respawn_time, respawn_variance | _rest] ->
        with {:ok, amount} <- to_int(amount),
             {:ok, respawn_time} <- to_int(respawn_time),
             {:ok, respawn_variance} <- to_int(respawn_variance),
             do: {:ok, mob_token(mob), amount, respawn_time, respawn_variance}

      _ ->
        :error
    end
  end

  @spec mob_token(String.t()) :: integer() | String.t()
  defp mob_token(mob) do
    case to_int(mob) do
      {:ok, id} -> id
      :error -> mob
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
