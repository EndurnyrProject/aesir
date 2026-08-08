defmodule Aesir.ZoneServer.Npc.Shops.Importer do
  @moduledoc """
  Parses shop script lines into our shop YAML maps.

  A shop line is four tab-separated columns:

      <map>,<x>,<y>,<facing>	shop	<NPC Name>	<sprite>{,<discount>},<itemid>:<price>{,...}

  Unlike warps, the NPC name column may contain spaces (e.g. `Tool Dealer#alb`),
  so the line is split on **tabs**, not on whitespace; only the first and fourth
  columns are then split on `,`. `facing` is stored as `dir`; `map` is clean
  (no `.gat`). The name's `#suffix` makes the placement unique: `id` keeps the
  full string, `name` is the display part before the first `#`.

  The fourth column begins with the sprite (numeric class id used as-is, or a
  string constant such as `HIDDEN_NPC` which falls back to a default merchant
  sprite). An optional bare `yes`/`no` discount token may follow the sprite and
  controls whether skill-based discounts apply; omitting it enables discounts. The
  remaining `itemid:price` pairs become buy-list items, with `price == -1`
  mapped to `nil` (fall back to `ItemDefinition.buy`).

  A `duplicate(<label>)` line carries no items of its own; it yields
  `{:duplicate, label, partial_map}` so the import task can fill its items from
  the source shop named `label`.

  Pure functions - the boot-safety checks against `MapCache` and the item DB
  live in the `Mix.Tasks.Aesir.Import.Shops` task, not here.
  """

  # Generic visible merchant sprite (Tool Dealer), used when a shop's sprite is
  # an unresolved string constant; sprite-name -> id resolution is a follow-on.
  @default_sprite 83

  @type shop_map :: %{String.t() => String.t() | non_neg_integer() | [map()]}

  @doc """
  Parses one shop script line.

    * `{:ok, shop_map}` - a valid placed plain shop, keyed as our YAML schema
    * `{:duplicate, label, shop_map}` - a `duplicate(<label>)` placement (no items)
    * `:skip` - a blank line, `//` comment, non-shop line, floating (`-`) shop,
      or non-UTF-8 line
    * `{:error, reason}` - a `shop`/`duplicate(...)` line that fails to parse
  """
  @spec parse_line(String.t()) ::
          {:ok, shop_map()} | {:duplicate, String.t(), shop_map()} | :skip | {:error, term()}
  def parse_line(line) when is_binary(line) do
    if String.valid?(line) do
      classify(String.trim(line))
    else
      :skip
    end
  end

  @spec classify(String.t()) ::
          {:ok, shop_map()} | {:duplicate, String.t(), shop_map()} | :skip | {:error, term()}
  defp classify(""), do: :skip
  defp classify("//" <> _), do: :skip

  defp classify(line) do
    case String.split(line, ~r/\t+/, trim: true) do
      [position, type, name, params] -> parse_shop(type, position, name, params)
      _ -> :skip
    end
  end

  @spec parse_shop(String.t(), String.t(), String.t(), String.t()) ::
          {:ok, shop_map()} | {:duplicate, String.t(), shop_map()} | :skip | {:error, term()}
  defp parse_shop("shop", position, name, params), do: build_shop(position, name, params)

  defp parse_shop("duplicate(" <> rest, position, name, params),
    do: build_duplicate(String.trim_trailing(rest, ")"), position, name, params)

  defp parse_shop(_type, _position, _name, _params), do: :skip

  @spec build_shop(String.t(), String.t(), String.t()) ::
          {:ok, shop_map()} | :skip | {:error, term()}
  defp build_shop(position, name, params) do
    with {:ok, {map, x, y, dir}} <- parse_position(position),
         [sprite_token | rest] <- String.split(params, ","),
         {:ok, discount, items} <- parse_items(rest) do
      {:ok,
       %{
         "id" => name,
         "name" => display_name(name),
         "map" => map,
         "x" => x,
         "y" => y,
         "dir" => dir,
         "sprite" => sprite(sprite_token),
         "items" => items,
         "discount" => discount
       }}
    else
      :skip -> :skip
      _ -> {:error, {:malformed, position, params}}
    end
  end

  @spec build_duplicate(String.t(), String.t(), String.t(), String.t()) ::
          {:duplicate, String.t(), shop_map()} | :skip | {:error, term()}
  defp build_duplicate(label, position, name, params) do
    with {:ok, {map, x, y, dir}} <- parse_position(position),
         [sprite_token | _] <- String.split(params, ",") do
      {:duplicate, label,
       %{
         "id" => name,
         "name" => display_name(name),
         "map" => map,
         "x" => x,
         "y" => y,
         "dir" => dir,
         "sprite" => sprite(sprite_token)
       }}
    else
      :skip -> :skip
      _ -> {:error, {:malformed, position, params}}
    end
  end

  @spec parse_position(String.t()) ::
          {:ok, {String.t(), non_neg_integer(), non_neg_integer(), non_neg_integer()}}
          | :skip
          | :error
  defp parse_position(position) do
    with [map, x, y, facing] <- String.split(position, ","),
         {:ok, x} <- to_int(x),
         {:ok, y} <- to_int(y),
         {:ok, dir} <- to_int(facing) do
      {:ok, {map, x, y, dir}}
    else
      ["-"] -> :skip
      _ -> :error
    end
  end

  @spec parse_items([String.t()]) :: {:ok, boolean(), [map()]} | :error
  defp parse_items(tokens) do
    {discount, tokens} = parse_discount(tokens)

    tokens
    |> Enum.reduce_while({:ok, []}, fn token, {:ok, acc} ->
      case parse_item(token) do
        {:ok, item} -> {:cont, {:ok, [item | acc]}}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      {:ok, items} -> {:ok, discount, Enum.reverse(items)}
      :error -> :error
    end
  end

  @spec parse_discount([String.t()]) :: {boolean(), [String.t()]}
  defp parse_discount(["yes" | rest]), do: {true, rest}
  defp parse_discount(["no" | rest]), do: {false, rest}
  defp parse_discount(tokens), do: {true, tokens}

  @spec parse_item(String.t()) :: {:ok, map()} | :error
  defp parse_item(token) do
    with [id, price] <- String.split(token, ":"),
         {:ok, nameid} <- to_int(id),
         {:ok, price} <- parse_price(price) do
      {:ok, %{"id" => nameid, "price" => price}}
    else
      _ -> :error
    end
  end

  @spec parse_price(String.t()) :: {:ok, non_neg_integer() | nil} | :error
  defp parse_price("-1"), do: {:ok, nil}
  defp parse_price(price), do: to_int(price)

  @spec sprite(String.t()) :: non_neg_integer()
  defp sprite(token) do
    case to_int(token) do
      {:ok, n} when n >= 0 -> n
      _ -> @default_sprite
    end
  end

  @spec display_name(String.t()) :: String.t()
  defp display_name(name), do: name |> String.split("#", parts: 2) |> hd()

  @spec to_int(String.t()) :: {:ok, integer()} | :error
  defp to_int(str) do
    case Integer.parse(str) do
      {n, ""} -> {:ok, n}
      _ -> :error
    end
  end
end
