defmodule Aesir.ZoneServer.Script.Rathena do
  @moduledoc """
  Tiny runtime helpers bridging rAthena script semantics into transpiled
  Elixir NPC modules.

  rAthena has no booleans: conditions are integers (`0` false, anything else
  true), comparisons evaluate to `1`/`0`, `+` concatenates when either side is
  a string, and arrays are sparse int-indexed with `0`/`""` defaults. The
  codegen emits calls to these helpers wherever those semantics leak into
  expression position.

  String indexing follows Elixir's Unicode grapheme semantics rather than
  rAthena's raw byte offsets.
  """

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @doc "rAthena truthiness: `0` and `\"\"` are false, everything else true."
  @spec truthy?(term()) :: boolean()
  def truthy?(0), do: false
  def truthy?(""), do: false
  def truthy?(false), do: false
  def truthy?(nil), do: false
  def truthy?(_), do: true

  @doc "A boolean in value position: rAthena comparisons yield `1`/`0`."
  @spec bool_int(boolean()) :: 0 | 1
  def bool_int(true), do: 1
  def bool_int(false), do: 0

  @doc "rAthena `+` on strings: concatenates, coercing numbers."
  @spec concat(term(), term()) :: String.t()
  def concat(a, b), do: to_string(a) <> to_string(b)

  @doc """
  rAthena `atoi`: C-style leading-integer parse of a string — skips leading
  whitespace, accepts an optional sign, and returns `0` when no digits follow.
  Integers pass through unchanged.
  """
  @spec atoi(term()) :: integer()
  def atoi(value) when is_integer(value), do: value

  def atoi(value) when is_binary(value) do
    case Integer.parse(String.trim_leading(value)) do
      {int, _rest} -> int
      :error -> 0
    end
  end

  def atoi(_value), do: 0

  @doc """
  Writes `value` at `index` of a script array, padding the gap with `pad`
  (rAthena arrays are sparse with implicit defaults).
  """
  @spec put_at(list(), non_neg_integer(), term(), term()) :: list()
  def put_at(list, index, value, _pad) when index < length(list),
    do: List.replace_at(list, index, value)

  def put_at(list, index, value, pad),
    do: list ++ List.duplicate(pad, index - length(list)) ++ [value]

  @doc "Writes consecutive `values` into a sparse script array from `index`."
  @spec put_many(list(), non_neg_integer(), list(), term()) :: list()
  def put_many(list, index, values, pad) do
    values
    |> Enum.with_index(index)
    |> Enum.reduce(list, fn {value, at}, acc -> put_at(acc, at, value, pad) end)
  end

  @doc "Splits a string on the first grapheme of `delimiter`, preserving empty fields."
  @spec explode(term(), term()) :: [String.t()]
  def explode(value, delimiter) do
    string = stringify(value)

    case delimiter |> stringify() |> String.first() do
      nil -> [string]
      delimiter -> String.split(string, delimiter, trim: false)
    end
  end

  @doc """
  Deletes `count` elements of a script array starting at `index`, shifting
  later values down (rAthena `deletearray`); `:rest` deletes everything from
  `index` to the end.
  """
  @spec delete_at(list(), non_neg_integer(), non_neg_integer() | :rest) :: list()
  def delete_at(list, index, :rest), do: Enum.take(list, index)

  def delete_at(list, index, count),
    do: Enum.take(list, index) ++ Enum.drop(list, index + count)

  @doc """
  Clamps an integer `input` result to `[min, max]`, returning `{status, value}`
  where status is rAthena's `input` return: `0` in range, `1` below min (value
  clamped to min), `2` above max (value clamped to max).
  """
  @spec input_int(integer() | term(), integer(), integer()) :: {0 | 1 | 2, term()}
  def input_int(raw, min, _max) when is_integer(raw) and raw < min, do: {1, min}
  def input_int(raw, _min, max) when is_integer(raw) and raw > max, do: {2, max}
  def input_int(raw, _min, _max), do: {0, raw}

  @doc """
  Length-checks a string `input` result against `[min, max]`, returning
  `{status, value}` where status is rAthena's `input` return: `0` in range,
  `1` too short, `2` too long. The string itself is returned unchanged.
  """
  @spec input_str(String.t() | term(), integer(), integer()) :: {0 | 1 | 2, term()}
  def input_str(raw, min, max) when is_binary(raw) do
    len = String.length(raw)

    cond do
      len < min -> {1, raw}
      len > max -> {2, raw}
      true -> {0, raw}
    end
  end

  def input_str(raw, _min, _max), do: {0, raw}

  @doc "Case-insensitive substring test, returned as rAthena's `1`/`0`."
  @spec compare(term(), term()) :: 0 | 1
  def compare(string, substring) do
    string
    |> stringify()
    |> String.downcase()
    |> String.contains?(substring |> stringify() |> String.downcase())
    |> bool_int()
  end

  @doc "Returns the number of Unicode graphemes in `value`."
  @spec getstrlen(term()) :: non_neg_integer()
  def getstrlen(value), do: value |> stringify() |> String.length()

  @doc "Returns the grapheme at `index`, or an empty string when out of range."
  @spec charat(term(), integer()) :: String.t()
  def charat(_value, index) when index < 0, do: ""
  def charat(value, index), do: String.at(stringify(value), index) || ""

  @doc "Returns `1` when the grapheme at `index` is a Unicode letter, otherwise `0`."
  @spec charisalpha(term(), integer()) :: 0 | 1
  def charisalpha(value, index) do
    case charat(value, index) do
      "" -> 0
      grapheme -> bool_int(Regex.match?(~r/^\p{L}$/u, grapheme))
    end
  end

  @doc "Returns the inclusive grapheme slice from `start_index` through `end_index`."
  @spec substr(term(), integer(), integer()) :: String.t()
  def substr(value, start_index, end_index) do
    string = stringify(value)

    if start_index >= 0 and start_index <= end_index and end_index < String.length(string) do
      String.slice(string, start_index, end_index - start_index + 1)
    else
      ""
    end
  end

  @doc "Uppercases a value using Elixir's Unicode-aware casing."
  @spec strtoupper(term()) :: String.t()
  def strtoupper(value), do: value |> stringify() |> String.upcase()

  @doc "Lowercases a value using Elixir's Unicode-aware casing."
  @spec strtolower(term()) :: String.t()
  def strtolower(value), do: value |> stringify() |> String.downcase()

  @doc "Inserts the first grapheme of `character` at a clamped grapheme index."
  @spec insertchar(term(), term(), integer()) :: String.t()
  def insertchar(value, character, index) do
    string = stringify(value)
    character = character |> stringify() |> String.first() || ""
    index = index |> max(0) |> min(String.length(string))
    {left, right} = String.split_at(string, index)
    left <> character <> right
  end

  @doc "Removes the grapheme at `index`, returning the string unchanged when out of range."
  @spec delchar(term(), integer()) :: String.t()
  def delchar(value, index) do
    string = stringify(value)

    if index >= 0 and index < String.length(string) do
      String.slice(string, 0, index) <> String.slice(string, index + 1, String.length(string))
    else
      string
    end
  end

  @doc "Returns the grapheme index of `needle` at or after `offset`, or `-1`."
  @spec strpos(term(), term(), integer()) :: integer()
  def strpos(haystack, needle, offset \\ 0)
  def strpos(_haystack, _needle, offset) when offset < 0, do: -1

  def strpos(haystack, needle, offset) do
    haystack = stringify(haystack)
    needle = stringify(needle)
    {_before, searchable} = String.split_at(haystack, offset)

    case needle == "" or :binary.match(searchable, needle) do
      true -> -1
      :nomatch -> -1
      {byte_index, _length} -> offset + grapheme_length_before(searchable, byte_index)
    end
  end

  @doc "Counts non-overlapping occurrences, case-sensitive unless `usecase` is `0`."
  @spec countstr(term(), term(), integer()) :: non_neg_integer()
  def countstr(input, search, usecase \\ 1) do
    input = stringify(input)
    search = stringify(search)

    with false <- search == "",
         {:ok, regex} <- literal_regex(search, usecase) do
      regex |> Regex.scan(input) |> length()
    else
      _ -> 0
    end
  end

  @doc "Replaces all non-overlapping occurrences, case-sensitive unless `usecase` is `0`."
  @spec replacestr(term(), term(), term()) :: String.t()
  def replacestr(input, search, replacement),
    do: replace_matches(input, search, replacement, 1, :infinity)

  @doc "Replaces occurrences with optional case sensitivity."
  @spec replacestr(term(), term(), term(), integer()) :: String.t()
  def replacestr(input, search, replacement, usecase),
    do: replace_matches(input, search, replacement, usecase, :infinity)

  @doc "Replaces at most `count` occurrences with optional case sensitivity."
  @spec replacestr(term(), term(), term(), integer(), integer()) :: String.t()
  def replacestr(input, search, replacement, usecase, count) when count > 0,
    do: replace_matches(input, search, replacement, usecase, count)

  def replacestr(input, _search, _replacement, _usecase, _count), do: stringify(input)

  @doc "Returns the number of regex captures (including the full match), or `0`."
  @spec preg_match(term(), term(), integer()) :: non_neg_integer()
  def preg_match(pattern, subject, offset \\ 0)
  def preg_match(_pattern, _subject, offset) when offset < 0, do: 0

  def preg_match(pattern, subject, offset) do
    subject = stringify(subject)
    byte_offset = subject |> String.split_at(offset) |> elem(0) |> byte_size()

    with {:ok, regex} <- Regex.compile(stringify(pattern)),
         captures when is_list(captures) <- Regex.run(regex, subject, offset: byte_offset) do
      length(captures)
    else
      _ -> 0
    end
  end

  @doc "Raises an integer base to an integer exponent and truncates fractional results."
  @spec pow(integer(), integer()) :: integer()
  def pow(base, exponent) when exponent >= 0, do: Integer.pow(base, exponent)
  def pow(base, exponent), do: base |> :math.pow(exponent) |> trunc()

  @doc "Looks up an item's display name by numeric id or Aegis name; unknown items are `\"null\"`."
  @spec getitemname(integer() | String.t()) :: String.t()
  def getitemname(item) when is_integer(item) do
    case Items.by_id(item) do
      {:ok, %ItemDefinition{name: name}} -> name
      :error -> "null"
    end
  end

  def getitemname(item) when is_binary(item) do
    case Items.by_aegis(item) do
      {:ok, %ItemDefinition{name: name}} -> name
      :error -> "null"
    end
  end

  @doc "Formats sequential `%s`/`%d` placeholders and literal `%%` in Elixir."
  @spec format(term(), [term()]) :: String.t()
  def format(template, args) when is_list(args) do
    case do_format(stringify(template), args, []) do
      {:ok, output} -> IO.iodata_to_binary(Enum.reverse(output))
      :error -> ""
    end
  end

  defp do_format("", _args, output), do: {:ok, output}
  defp do_format("%%" <> rest, args, output), do: do_format(rest, args, ["%" | output])

  defp do_format("%s" <> rest, [arg | args], output),
    do: do_format(rest, args, [stringify(arg) | output])

  defp do_format("%d" <> rest, [arg | args], output),
    do: do_format(rest, args, [arg |> integer_value() |> Integer.to_string() | output])

  defp do_format(<<"%", specifier, _rest::binary>>, [], _output)
       when specifier in [?s, ?d],
       do: :error

  defp do_format(<<byte, rest::binary>>, args, output),
    do: do_format(rest, args, [<<byte>> | output])

  defp replace_matches(input, search, replacement, usecase, count) do
    input = stringify(input)
    search = stringify(search)
    replacement = stringify(replacement)

    with false <- search == "",
         {:ok, regex} <- literal_regex(search, usecase) do
      do_replace(input, regex, replacement, count, [])
    else
      _ -> input
    end
  end

  defp do_replace(input, _regex, _replacement, 0, output),
    do: output |> Enum.reverse([input]) |> IO.iodata_to_binary()

  defp do_replace(input, regex, replacement, count, output) do
    case Regex.run(regex, input, return: :index) do
      [{byte_index, byte_length} | _captures] ->
        prefix = binary_part(input, 0, byte_index)
        rest_index = byte_index + byte_length
        rest = binary_part(input, rest_index, byte_size(input) - rest_index)
        next_count = if count == :infinity, do: :infinity, else: count - 1
        do_replace(rest, regex, replacement, next_count, [replacement, prefix | output])

      nil ->
        output |> Enum.reverse([input]) |> IO.iodata_to_binary()
    end
  end

  defp literal_regex(search, usecase) do
    options = if usecase == 0, do: "iu", else: "u"
    search |> Regex.escape() |> Regex.compile(options)
  end

  defp grapheme_length_before(string, byte_index) do
    string |> binary_part(0, byte_index) |> String.length()
  end

  defp integer_value(value) when is_integer(value), do: value
  defp integer_value(value), do: atoi(stringify(value))

  defp stringify(value) when is_binary(value), do: value
  defp stringify(value), do: to_string(value)
end
