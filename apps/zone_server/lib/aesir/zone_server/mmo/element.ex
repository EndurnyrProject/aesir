defmodule Aesir.ZoneServer.Mmo.Element do
  @moduledoc """
  Shared attack and defense element types and numeric IDs.

  Element interactions belong to the mode-specific combat formulas. Script
  selectors and restricted domains such as forgeable elements remain separate.
  """

  @typedoc "An attack or defense element."
  @type t ::
          :neutral
          | :water
          | :earth
          | :fire
          | :wind
          | :poison
          | :holy
          | :shadow
          | :ghost
          | :undead

  @typedoc "Defense element level."
  @type level :: 1..4

  @ids %{
    neutral: 0,
    water: 1,
    earth: 2,
    fire: 3,
    wind: 4,
    poison: 5,
    holy: 6,
    shadow: 7,
    ghost: 8,
    undead: 9
  }
  @by_id Map.new(@ids, fn {element, id} -> {id, element} end)

  @doc """
  Returns the numeric ID, using `default` for unknown elements.

  The default is `0` (neutral). Formula lookups use `nil` to distinguish an
  unknown element from neutral without duplicating the ID table.
  """
  @spec id(atom()) :: 0..9
  @spec id(atom(), integer() | nil) :: integer() | nil
  def id(element, default \\ 0), do: Map.get(@ids, element, default)

  @doc "Returns the element for a numeric ID, raising `KeyError` for unknown IDs."
  @spec from_id!(integer()) :: t()
  def from_id!(id), do: Map.fetch!(@by_id, id)
end
