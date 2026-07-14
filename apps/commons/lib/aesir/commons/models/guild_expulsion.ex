defmodule Aesir.Commons.Models.GuildExpulsion do
  @moduledoc """
  An append-only record of a character expelled from a guild.

  Written by `Guild.Manager.expel/4` alongside resetting the target's
  `guild_id`/`guild_position`. Kept so a later re-invite can be traced back
  to a prior expulsion; there is no delete or update path.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          guild_id: integer() | nil,
          char_id: integer() | nil,
          name: String.t() | nil,
          account_id: integer() | nil,
          reason: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "guild_expulsions" do
    field :guild_id, :integer
    field :char_id, :integer
    field :name, :string
    field :account_id, :integer
    field :reason, :string

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for a guild expulsion record.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild_expulsion, attrs) do
    guild_expulsion
    |> cast(attrs, [:guild_id, :char_id, :name, :account_id, :reason])
    |> validate_required([:guild_id, :char_id, :name, :account_id])
  end
end
