defmodule Aesir.Commons.Models.Party do
  @moduledoc """
  Party model — persistence source of truth for party existence and options.

  Membership itself stays on the existing `characters.party_id` column; this
  schema only tracks the party's name, leader, even-share option, and item pickup-share option.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          leader_char_id: integer() | nil,
          exp_share: boolean(),
          item_pickup_share: boolean(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "parties" do
    field :name, :string
    field :leader_char_id, :integer
    field :exp_share, :boolean, default: false
    field :item_pickup_share, :boolean, default: false

    timestamps()
  end

  @doc """
  Creates a changeset for a party.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(party, attrs) do
    party
    |> cast(attrs, [:name, :leader_char_id, :exp_share, :item_pickup_share])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :leader_char_id])
    |> validate_length(:name, min: 1)
    |> unique_constraint(:name)
  end

  @doc """
  Builds a changeset for a new party from the given attrs.
  """
  @spec new(map()) :: Ecto.Changeset.t()
  def new(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
