defmodule Aesir.ZoneServer.Script.Rathena do
  @moduledoc """
  Tiny runtime helpers bridging rAthena script semantics into transpiled
  Elixir NPC modules.

  rAthena has no booleans: conditions are integers (`0` false, anything else
  true), comparisons evaluate to `1`/`0`, `+` concatenates when either side is
  a string, and arrays are sparse int-indexed with `0`/`""` defaults. The
  codegen emits calls to these helpers wherever those semantics leak into
  expression position.
  """

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
  Writes `value` at `index` of a script array, padding the gap with `pad`
  (rAthena arrays are sparse with implicit defaults).
  """
  @spec put_at(list(), non_neg_integer(), term(), term()) :: list()
  def put_at(list, index, value, _pad) when index < length(list),
    do: List.replace_at(list, index, value)

  def put_at(list, index, value, pad),
    do: list ++ List.duplicate(pad, index - length(list)) ++ [value]

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
end
