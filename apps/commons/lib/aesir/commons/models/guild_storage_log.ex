defmodule Aesir.Commons.Models.GuildStorageLog do
  @moduledoc """
  Append-only audit record for a guild storage transfer.

  Guild disbanding hard-deletes its row, so cascading foreign keys would erase this
  history and restricting foreign keys would block disbanding. The guild and character
  IDs are deliberately unconstrained so the audit trail outlives both; do not convert
  them to foreign keys.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          guild_id: integer() | nil,
          char_id: integer() | nil,
          nameid: integer(),
          amount: integer() | nil,
          refine: integer(),
          card0: integer(),
          card1: integer(),
          card2: integer(),
          card3: integer(),
          unique_id: integer(),
          inserted_at: NaiveDateTime.t() | nil
        }

  schema "guild_storage_log" do
    field :guild_id, :integer
    field :char_id, :integer
    field :nameid, :integer, default: 0
    field :amount, :integer
    field :refine, :integer, default: 0
    field :card0, :integer, default: 0
    field :card1, :integer, default: 0
    field :card2, :integer, default: 0
    field :card3, :integer, default: 0
    field :unique_id, :integer, default: 0

    timestamps(updated_at: false)
  end

  @doc """
  Creates a changeset for a guild storage audit record.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :guild_id,
      :char_id,
      :nameid,
      :amount,
      :refine,
      :card0,
      :card1,
      :card2,
      :card3,
      :unique_id
    ])
    |> validate_required([:guild_id, :char_id, :nameid, :amount])
  end
end
