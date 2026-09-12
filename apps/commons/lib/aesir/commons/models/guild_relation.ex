defmodule Aesir.Commons.Models.GuildRelation do
  @moduledoc """
  A directed guild relation: `guild_id` sees `other_guild_id` as an ally or
  an antagonist. Rows are directed, so a mutual alliance is two rows, one
  per guild. `other_name` mirrors the other guild's name at the time the
  relation was formed so it can be displayed without an extra lookup.

  Persistence layer only; nothing reads or writes rows yet.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @valid_kinds ~w(ally antagonist)

  @type t :: %__MODULE__{
          id: integer() | nil,
          guild_id: integer() | nil,
          other_guild_id: integer() | nil,
          kind: String.t() | nil,
          other_name: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "guild_relations" do
    field :guild_id, :integer
    field :other_guild_id, :integer
    field :kind, :string
    field :other_name, :string

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for a guild relation record.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild_relation, attrs) do
    guild_relation
    |> cast(attrs, [:guild_id, :other_guild_id, :kind, :other_name])
    |> validate_required([:guild_id, :other_guild_id, :kind, :other_name])
    |> validate_inclusion(:kind, @valid_kinds)
    |> unique_constraint([:guild_id, :other_guild_id])
    |> foreign_key_constraint(:guild_id)
    |> foreign_key_constraint(:other_guild_id)
  end
end
