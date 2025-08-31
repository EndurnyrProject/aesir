defmodule Aesir.Commons.Models.InventoryItem do
  @moduledoc """
  InventoryItem model representing a character's inventory item.

  Based on rAthena's item structure, this model handles:
  - Basic item data (nameid, amount)
  - Equipment positioning (equip, equip_switch)
  - Item enhancement (refine, cards, random options)
  - Item metadata (identification, binding, expiration)
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aesir.Commons.Models.Character

  @type t :: %__MODULE__{
          id: integer(),
          char_id: integer(),
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
          expire_time: NaiveDateTime.t() | nil,
          favorite: integer(),
          bound: integer(),
          unique_id: integer(),
          equip_switch: integer(),
          enchant_grade: integer(),
          character: Character.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t(),
          updated_at: NaiveDateTime.t()
        }

  schema "inventory" do
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
    field :expire_time, :naive_datetime
    field :favorite, :integer, default: 0
    field :bound, :integer, default: 0
    field :unique_id, :integer, default: 0
    field :equip_switch, :integer, default: 0
    field :enchant_grade, :integer, default: 0

    timestamps()
  end

  @doc """
  Creates a changeset for an item.
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

  @doc """
  Returns the cards as a list for easier manipulation.
  """
  @spec cards(t()) :: [integer()]
  def cards(%__MODULE__{card0: c0, card1: c1, card2: c2, card3: c3}) do
    [c0, c1, c2, c3]
  end

  @doc """
  Checks if the item is equipped in any position.
  """
  @spec equipped?(t()) :: boolean()
  def equipped?(%__MODULE__{equip: equip}) when equip > 0, do: true
  def equipped?(_), do: false

  @doc """
  Checks if the item is identified.
  """
  @spec identified?(t()) :: boolean()
  def identified?(%__MODULE__{identify: 1}), do: true
  def identified?(_), do: false

  @doc """
  Checks if the item is bound to the character.
  """
  @spec bound?(t()) :: boolean()
  def bound?(%__MODULE__{bound: bound}) when bound > 0, do: true
  def bound?(_), do: false

  @doc """
  Checks if the item has expired.
  """
  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expire_time: nil}), do: false

  def expired?(%__MODULE__{expire_time: expire_time}) do
    NaiveDateTime.compare(expire_time, NaiveDateTime.utc_now()) == :lt
  end

  @doc """
  Gets the random option value for a specific option ID.
  """
  @spec get_random_option(t(), integer()) :: %{val: integer(), parm: integer()} | nil
  def get_random_option(%__MODULE__{random_options: options}, option_id) do
    Map.get(options, to_string(option_id))
  end

  @doc """
  Adds or updates a random option on the item.
  """
  @spec put_random_option(t(), integer(), integer(), integer()) :: t()
  def put_random_option(%__MODULE__{random_options: options} = item, option_id, val, parm) do
    new_options = Map.put(options, to_string(option_id), %{val: val, parm: parm})
    %{item | random_options: new_options}
  end
end
