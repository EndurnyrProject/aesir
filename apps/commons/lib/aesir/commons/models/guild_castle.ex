defmodule Aesir.Commons.Models.GuildCastle do
  @moduledoc """
  GuildCastle model — durable castle ownership for WoE sieges.

  One row per FE castle (`castle_id` 0..19), seeded by the migration.
  `guild_id` is nullable: nil means the castle is unoccupied. `economy` and
  `defense` are Phase-2 placeholders, currently inert.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          castle_id: integer() | nil,
          guild_id: integer() | nil,
          economy: non_neg_integer(),
          defense: non_neg_integer(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "guild_castles" do
    field :castle_id, :integer
    field :guild_id, :integer
    field :economy, :integer, default: 0
    field :defense, :integer, default: 0

    timestamps()
  end

  @doc """
  Creates a changeset for a guild castle.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild_castle, attrs) do
    guild_castle
    |> cast(attrs, [:castle_id, :guild_id, :economy, :defense])
    |> validate_required([:castle_id, :economy, :defense])
    |> validate_number(:economy, greater_than_or_equal_to: 0)
    |> validate_number(:defense, greater_than_or_equal_to: 0)
    |> unique_constraint(:castle_id)
  end

  @doc """
  Builds a changeset for a new guild castle from the given attrs.
  """
  @spec new(map()) :: Ecto.Changeset.t()
  def new(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
