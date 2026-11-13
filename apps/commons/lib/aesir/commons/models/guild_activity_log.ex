defmodule Aesir.Commons.Models.GuildActivityLog do
  @moduledoc """
  One row of a guild's activity log: who joined, left, was promoted, which
  skill was raised, which guild became an ally, which castle was taken.

  Unlike `Aesir.Commons.Models.GuildStorageLog` this is a feed shown to the
  guild's own members, not an audit trail, so the rows are deleted with the
  guild (`guild_id` cascades).

  `kind` says which of `subject`, `actor`, `detail`, `skill_id` and `level` an
  entry fills; the rest keep their empty defaults.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @kinds ~w(created joined left expelled position_changed skill_learned level_up
            alliance_formed alliance_broken antagonist_declared antagonist_removed
            castle_taken castle_lost)

  @type t :: %__MODULE__{
          id: integer() | nil,
          guild_id: integer() | nil,
          kind: String.t() | nil,
          subject: String.t(),
          actor: String.t(),
          detail: String.t(),
          skill_id: integer(),
          level: integer(),
          inserted_at: DateTime.t() | nil
        }

  schema "guild_activity_log" do
    field :guild_id, :integer
    field :kind, :string
    field :subject, :string, default: ""
    field :actor, :string, default: ""
    field :detail, :string, default: ""
    field :skill_id, :integer, default: 0
    field :level, :integer, default: 0

    timestamps(updated_at: false, type: :utc_datetime)
  end

  @doc """
  Creates a changeset for a guild activity entry.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(log, attrs) do
    log
    |> cast(attrs, [:guild_id, :kind, :subject, :actor, :detail, :skill_id, :level],
      empty_values: []
    )
    |> validate_required([:guild_id, :kind])
    |> validate_inclusion(:kind, @kinds)
    |> foreign_key_constraint(:guild_id)
  end
end
