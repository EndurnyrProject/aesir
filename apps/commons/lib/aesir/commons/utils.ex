defmodule Aesir.Commons.Utils do
  @moduledoc """
  Common utility functions used across the Aesir codebase.
  """

  @doc """
  Returns the value if not nil, otherwise returns the default value.
  Useful for packet serialization where nil fields need default values.

  ## Examples

      iex> Aesir.Commons.Utils.get_field(42, 0)
      42

      iex> Aesir.Commons.Utils.get_field(nil, 0)
      0
  """
  @spec get_field(any(), any()) :: any()
  def get_field(nil, default), do: default
  def get_field(value, _default), do: value

  def int_to_sex(0), do: "F"
  def int_to_sex(1), do: "M"

  def sex_to_int("F"), do: 0
  def sex_to_int("M"), do: 1
end
