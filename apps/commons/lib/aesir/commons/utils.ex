defmodule Aesir.Commons.Utils do
  @moduledoc """
  Common utility functions used across the Aesir codebase.
  """

  def int_to_sex(0), do: "F"
  def int_to_sex(1), do: "M"
end
