defmodule Aesir.Commons.Models.CharacterStatus do
  @moduledoc """
  CharacterStatus model persisting a character's active status effects across
  logouts, mirroring rAthena's `sc_data` table.

  Rows are written on logout and consumed (loaded then deleted) on login, so
  the table only holds statuses of characters that are currently offline.
  `remaining_ms` stores how much of the status' duration was left at save
  time; `nil` means the status is permanent. Runtime-only fields of a status
  instance (`state`, `phase`) are not persisted — the effect's `on_apply`
  rebuilds them on restore.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aesir.Commons.Models.Character

  @type t :: %__MODULE__{
          id: integer() | nil,
          char_id: integer() | nil,
          status_type: String.t(),
          val1: integer(),
          val2: integer(),
          val3: integer(),
          val4: integer(),
          tick: integer(),
          flag: integer(),
          source_id: integer() | nil,
          remaining_ms: integer() | nil,
          character: Character.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "character_statuses" do
    belongs_to :character, Character, foreign_key: :char_id

    field :status_type, :string
    field :val1, :integer, default: 0
    field :val2, :integer, default: 0
    field :val3, :integer, default: 0
    field :val4, :integer, default: 0
    field :tick, :integer, default: 0
    field :flag, :integer, default: 0
    field :source_id, :integer
    field :remaining_ms, :integer

    timestamps()
  end

  @doc """
  Creates a changeset for a persisted character status.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(status, attrs) do
    status
    |> cast(attrs, [
      :char_id,
      :status_type,
      :val1,
      :val2,
      :val3,
      :val4,
      :tick,
      :flag,
      :source_id,
      :remaining_ms
    ])
    |> validate_required([:char_id, :status_type])
    |> unique_constraint([:char_id, :status_type])
    |> foreign_key_constraint(:char_id)
  end
end
