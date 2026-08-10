defmodule Aesir.Commons.Models.CartItem do
  @moduledoc """
  CartItem model representing an item stored in a character's cart.

  Mirrors `Aesir.Commons.Models.InventoryItem` but is persisted in the separate
  `cart_inventory` table. The `equip` field is kept for shape parity with the
  inventory schema even though cart items are never equipped.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aesir.Commons.Models.Character

  @type t :: %__MODULE__{
          id: integer() | nil,
          char_id: integer() | nil,
          nameid: integer(),
          amount: integer(),
          equip: integer(),
          identify: integer(),
          refine: integer(),
          attribute: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          random_options: map(),
          craft: map() | nil,
          expire_time: NaiveDateTime.t() | nil,
          favorite: integer(),
          bound: integer(),
          unique_id: integer(),
          equip_switch: integer(),
          enchant_grade: integer(),
          character: Character.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "cart_inventory" do
    belongs_to :character, Character, foreign_key: :char_id

    field :nameid, :integer, default: 0
    field :amount, :integer, default: 0
    field :equip, :integer, default: 0
    field :identify, :integer, default: 0
    field :refine, :integer, default: 0
    field :attribute, :integer, default: 0
    field :card0, :integer, default: 0
    field :card1, :integer, default: 0
    field :card2, :integer, default: 0
    field :card3, :integer, default: 0
    field :random_options, :map, default: %{}
    field :craft, :map
    field :expire_time, :naive_datetime
    field :favorite, :integer, default: 0
    field :bound, :integer, default: 0
    field :unique_id, :integer, default: 0
    field :equip_switch, :integer, default: 0
    field :enchant_grade, :integer, default: 0

    timestamps()
  end

  @doc """
  Creates a changeset for a cart item.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :char_id,
      :nameid,
      :amount,
      :equip,
      :identify,
      :refine,
      :attribute,
      :card0,
      :card1,
      :card2,
      :card3,
      :random_options,
      :craft,
      :expire_time,
      :favorite,
      :bound,
      :unique_id,
      :equip_switch,
      :enchant_grade
    ])
    |> validate_required([:char_id, :nameid, :amount])
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:refine, greater_than_or_equal_to: 0, less_than_or_equal_to: 20)
    |> validate_number(:enchant_grade, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:char_id)
  end
end
