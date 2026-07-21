defmodule Aesir.ZoneServer.Mmo.Skill.ForcedMovement do
  @moduledoc """
  A destination validated before a skill commits its resources.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.Cell

  typedstruct do
    field :map_name, String.t(), enforce: true
    field :x, integer(), enforce: true
    field :y, integer(), enforce: true
  end

  @type validation_error :: :out_of_range | :invalid_destination

  @spec validate(map(), integer(), integer(), non_neg_integer()) ::
          {:ok, t()} | {:error, validation_error()}
  def validate(%{map_name: map_name, x: from_x, y: from_y}, x, y, range)
      when is_integer(range) and range >= 0 do
    if Geometry.in_tile_range?(from_x, from_y, x, y, range) do
      if Cell.traversable?(map_name, x, y) do
        {:ok, %__MODULE__{map_name: map_name, x: x, y: y}}
      else
        {:error, :invalid_destination}
      end
    else
      {:error, :out_of_range}
    end
  end

  def validate(_caster, _x, _y, _range), do: {:error, :invalid_destination}
end
