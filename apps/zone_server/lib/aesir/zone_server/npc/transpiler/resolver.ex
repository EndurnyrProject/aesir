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

  alias Aesir.ZoneServer.Announcement.Flags
  alias Aesir.ZoneServer.Mmo.Emotion
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver, as: ItemResolver

  @doc """
  Resolves a bare constant to an Elixir literal source string: booleans to
  `1`/`0` (rAthena semantics), `bc_*` broadcast flags to their integer value,
  job/status/element constants to their Aesir atoms.
  """
  @spec constant(String.t()) :: {:ok, String.t()} | :error
  def constant("true"), do: {:ok, "1"}
  def constant("false"), do: {:ok, "0"}

  def constant(symbol) do
    with :error <- flag_constant(symbol) do
      [
        &ItemResolver.resolve_class/1,
        &ItemResolver.resolve_status/1,
        &ItemResolver.resolve_element/1
      ]
      |> Enum.find_value(:error, &atom_constant(&1, symbol))
    end
  end

  defp flag_constant(symbol) do
    case Flags.value(symbol) do
      {:ok, value} -> {:ok, Integer.to_string(value)}
      :error -> :error
    end
  end

  defp atom_constant(resolver, symbol) do
    case resolver.(symbol) do
      {:ok, atom} -> {:ok, inspect(atom)}
      {:error, _} -> nil
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

  @doc """
  Resolves an `emotion` buildin argument. An `ET_*` token maps to its
  `Mmo.Emotion` atom key (`ET_MONEY` -> `:money`), validated against
  `Emotion.id/1`. A bare integer passes through unchanged, matching the
  `emotion` DSL op's `atom() | non_neg_integer()` argument.
  """
  @spec emote(String.t() | integer()) :: {:ok, atom() | integer()} | :error
  def emote(value) when is_integer(value), do: {:ok, value}

  def emote("ET_" <> _ = symbol) do
    with {:ok, atom} <- existing_atom(String.trim_leading(symbol, "ET_")),
         id when is_integer(id) <- Emotion.id(atom) do
      {:ok, atom}
    else
      _ -> :error
    end
  end

  def emote(symbol) when is_binary(symbol), do: :error

  @quest_modes %{
    "HAVEQUEST" => :havequest,
    "PLAYTIME" => :playtime,
    "HUNTING" => :hunting
  }

  @doc """
  Resolves a `checkquest`/`questprogress` mode constant (`HAVEQUEST`,
  `PLAYTIME`, `HUNTING`) to the `QuestLog.check/3` mode atom. rAthena spells
  these uppercase; unlike buildin names they are not case-insensitive.
  """
  @spec quest_mode(String.t()) :: {:ok, :havequest | :playtime | :hunting} | :error
  def quest_mode(symbol) when is_binary(symbol), do: Map.fetch(@quest_modes, symbol)

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

  @spec existing_atom(String.t()) :: {:ok, atom()} | :error
  defp existing_atom(symbol) do
    {:ok, String.to_existing_atom(String.downcase(symbol))}
  rescue
    ArgumentError -> :error
  end
end
