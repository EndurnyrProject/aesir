defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemCraft do
  @moduledoc """
  Models the identity metadata for signed and forged items.
  """

  @enforce_keys [:kind, :creator_char_id]
  defstruct [:kind, :creator_char_id, element: :neutral, star_crumbs: 0]

  @type kind :: :signed | :forged
  @type element :: :neutral | :water | :earth | :fire | :wind
  @type t :: %__MODULE__{
          kind: kind(),
          creator_char_id: non_neg_integer(),
          element: element(),
          star_crumbs: 0..3
        }

  @doc "Builds metadata for a signed item."
  @spec signed(non_neg_integer()) :: t()
  def signed(creator_char_id) do
    %__MODULE__{kind: :signed, creator_char_id: creator_char_id}
  end

  @doc "Builds metadata for a forged item."
  @spec forged(element(), 0..3, non_neg_integer()) :: t()
  def forged(element, star_crumbs, creator_char_id) when star_crumbs in 0..3 do
    %__MODULE__{
      kind: :forged,
      creator_char_id: creator_char_id,
      element: element,
      star_crumbs: star_crumbs
    }
  end

  @doc "Returns the combat damage granted by star crumbs."
  @spec star_damage(t()) :: non_neg_integer()
  def star_damage(%__MODULE__{kind: :signed}), do: 0
  def star_damage(%__MODULE__{kind: :forged, star_crumbs: 3}), do: 40
  def star_damage(%__MODULE__{kind: :forged, star_crumbs: star_crumbs}), do: star_crumbs * 5

  @doc "Serializes item craft metadata for storage."
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = craft) do
    %{
      "kind" => Atom.to_string(craft.kind),
      "creator_char_id" => craft.creator_char_id,
      "element" => Atom.to_string(craft.element),
      "star_crumbs" => craft.star_crumbs
    }
  end

  @doc "Deserializes item craft metadata from storage."
  @spec from_map(map() | nil) :: {:ok, t()} | :error
  def from_map(%{
        "kind" => kind,
        "creator_char_id" => creator_char_id,
        "element" => element,
        "star_crumbs" => star_crumbs
      }) do
    with {:ok, kind} <- kind_from_string(kind),
         {:ok, element} <- element_from_string(element),
         true <- is_integer(creator_char_id) and creator_char_id >= 0,
         true <- is_integer(star_crumbs) and star_crumbs in 0..3 do
      craft(kind, element, star_crumbs, creator_char_id)
    else
      _invalid_metadata -> :error
    end
  end

  def from_map(_metadata), do: :error

  defp craft(:signed, :neutral, 0, creator_char_id), do: {:ok, signed(creator_char_id)}

  defp craft(:forged, element, star_crumbs, creator_char_id) do
    {:ok, forged(element, star_crumbs, creator_char_id)}
  end

  defp craft(_kind, _element, _star_crumbs, _creator_char_id), do: :error

  defp kind_from_string("signed"), do: {:ok, :signed}
  defp kind_from_string("forged"), do: {:ok, :forged}
  defp kind_from_string(_kind), do: :error

  defp element_from_string("neutral"), do: {:ok, :neutral}
  defp element_from_string("water"), do: {:ok, :water}
  defp element_from_string("earth"), do: {:ok, :earth}
  defp element_from_string("fire"), do: {:ok, :fire}
  defp element_from_string("wind"), do: {:ok, :wind}
  defp element_from_string(_element), do: :error
end
