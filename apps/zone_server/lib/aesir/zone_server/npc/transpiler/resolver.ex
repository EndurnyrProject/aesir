defmodule Aesir.ZoneServer.Npc.Transpiler.Resolver do
  @moduledoc """
  Resolves rAthena NPC script symbols at transpile time.

  Statuses, classes, elements, items and skills delegate to the item
  transpiler's curated `RathenaScript.Resolver`. On top of that this module
  resolves bare constants (`true`/`false`, `Job_*`, `SC_*`, `Ele_*`) for
  expression codegen, and NPC sprite constants (`4_F_KAFRA1`) via the
  `e_job_types` enum parsed straight out of rAthena's `src/map/npc.hpp` — the
  same table rAthena itself uses (script sprite names are the enum entries
  minus their `JT_` prefix).

  A symbol that resolves nowhere returns `:error`; the codegen then emits a
  raising `Todo.const!/1` and the report lists it.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver, as: ItemResolver

  @doc """
  Resolves a bare constant to an Elixir literal source string: booleans to
  `1`/`0` (rAthena semantics), job/status/element constants to their Aesir
  atoms.
  """
  @spec constant(String.t()) :: {:ok, String.t()} | :error
  def constant("true"), do: {:ok, "1"}
  def constant("false"), do: {:ok, "0"}

  def constant(symbol) do
    with :error <- atom_constant(&ItemResolver.resolve_class/1, symbol),
         :error <- atom_constant(&ItemResolver.resolve_status/1, symbol),
         :error <- atom_constant(&ItemResolver.resolve_element/1, symbol) do
      :error
    end
  end

  defp atom_constant(resolver, symbol) do
    case resolver.(symbol) do
      {:ok, atom} -> {:ok, inspect(atom)}
      {:error, _} -> :error
    end
  end

  @spec item(String.t() | integer()) :: {:ok, integer()} | :error
  def item(symbol) do
    case ItemResolver.resolve_item(symbol) do
      {:ok, id} -> {:ok, id}
      {:error, _} -> :error
    end
  end

  @spec status(String.t()) :: {:ok, atom()} | :error
  def status(symbol) do
    case ItemResolver.resolve_status(symbol) do
      {:ok, atom} -> {:ok, atom}
      {:error, _} -> :error
    end
  end

  # -- sprites -----------------------------------------------------------------

  @doc """
  Parses the `e_job_types` enum from rAthena's `src/map/npc.hpp` into a
  `%{"4_F_KAFRA1" => id}` map. Plain C enum: explicit `= N` anchors, +1
  otherwise; `JT_` prefixes stripped to match script sprite names.
  """
  @spec load_sprites(Path.t()) :: {:ok, %{String.t() => integer()}} | {:error, term()}
  def load_sprites(npc_hpp_path) do
    with {:ok, source} <- File.read(npc_hpp_path),
         [_, body] <- Regex.run(~r/enum e_job_types\s*\{(.*?)\};/s, source) do
      {:ok, parse_enum(body)}
    else
      nil -> {:error, :enum_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_enum(body) do
    body
    |> String.replace(~r{//[^\n]*}, "")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reduce({%{}, 0}, &enum_entry/2)
    |> elem(0)
  end

  defp enum_entry(entry, {acc, next}) do
    case Regex.run(~r/^(\w+)\s*(?:=\s*(-?\w+))?/, entry) do
      [_, name] -> {put_sprite(acc, name, next), next + 1}
      [_, name, value] -> with_value(acc, name, value, next)
      nil -> {acc, next}
    end
  end

  defp with_value(acc, name, value, next) do
    case Integer.parse(value) do
      {n, ""} -> {put_sprite(acc, name, n), n + 1}
      # `= OTHER_CONST` anchors (e.g. NPC_RANGE2_END) don't advance the counter
      _ -> {acc, next}
    end
  end

  defp put_sprite(acc, "JT_" <> name, value), do: Map.put(acc, name, value)
  defp put_sprite(acc, _other, _value), do: acc
end
