defmodule Aesir.Commons.Models.GuildStorageItem do
  @moduledoc """
  Item stored in a guild's shared storage.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aesir.Commons.Models.Guild

  @type t :: %__MODULE__{
          id: integer() | nil,
          guild_id: integer() | nil,
          nameid: integer(),
          amount: integer(),
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
          bound: integer(),
          unique_id: integer(),
          enchant_grade: integer(),
          guild: Guild.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "guild_storage" do
    belongs_to :guild, Guild

    field :nameid, :integer, default: 0
    field :amount, :integer, default: 0
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
    field :bound, :integer, default: 0
    field :unique_id, :integer, default: 0
    field :enchant_grade, :integer, default: 0

    timestamps()
  end

  @doc """
  Creates a changeset for a guild storage item.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, [
      :guild_id,
      :nameid,
      :amount,
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
      :bound,
      :unique_id,
      :enchant_grade
    ])
    |> validate_required([:guild_id, :nameid, :amount])
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:refine, greater_than_or_equal_to: 0, less_than_or_equal_to: 20)
    |> validate_number(:enchant_grade, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:guild_id)
  end
end
