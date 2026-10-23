defmodule Aesir.Commons.Models.ItemOptions do
  @moduledoc """
  An item's random options: its five option slots in order, each an
  `%{id, value, param}` entry.

  The list is positional: index `i` is option slot `i`, the order the client
  shows them in and the order their scripts run in. An entry with id `0` is an
  empty slot; all-zero slots after the last other one are dropped, so `[]` is
  an item without options. The same option id may fill more than one slot. The
  list is stored in a jsonb column; a row written before the list shape (an
  empty object) loads as no options.
  """

  use Ecto.Type

  @max_options 5

  @typedoc "One option slot: its option id (0 when empty), rolled value and parameter."
  @type option() :: %{id: integer(), value: integer(), param: integer()}

  @type t() :: [option()]

  @doc "The number of option slots an item has."
  @spec max_options() :: pos_integer()
  def max_options, do: @max_options

  @doc "Returns the options padded with empty slots to all five slots."
  @spec pad(t()) :: t()
  def pad(options),
    do: options ++ List.duplicate(%{id: 0, value: 0, param: 0}, @max_options - length(options))

  @doc "Returns the options without the all-zero slots after the last other one."
  @spec trim(t()) :: t()
  def trim(options) do
    options
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == %{id: 0, value: 0, param: 0}))
    |> Enum.reverse()
  end

  @impl true
  def type, do: :map

  @impl true
  def cast(options) when is_list(options), do: normalize(options)
  def cast(_options), do: :error

  @impl true
  def load(options) when options == %{}, do: {:ok, []}
  def load(options) when is_list(options), do: normalize(options)
  def load(_options), do: :error

  @impl true
  def dump(options) when is_list(options), do: normalize(options)
  def dump(_options), do: :error

  defp normalize(options) when length(options) <= @max_options do
    options
    |> Enum.reduce_while([], fn option, acc ->
      case option(option) do
        {:ok, option} -> {:cont, [option | acc]}
        :error -> {:halt, :error}
      end
    end)
    |> case do
      :error -> :error
      acc -> {:ok, acc |> Enum.reverse() |> trim()}
    end
  end

  defp normalize(_options), do: :error

  defp option(%{id: id, value: value, param: param}), do: option(id, value, param)

  defp option(%{"id" => id, "value" => value, "param" => param}),
    do: option(id, value, param)

  defp option(_option), do: :error

  defp option(id, value, param)
       when is_integer(id) and is_integer(value) and is_integer(param),
       do: {:ok, %{id: id, value: value, param: param}}

  defp option(_id, _value, _param), do: :error
end
