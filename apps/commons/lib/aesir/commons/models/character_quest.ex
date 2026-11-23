defmodule Aesir.Commons.Models.CharacterQuest do
  @moduledoc """
  CharacterQuest model persisting a character's quest log, mirroring
  rAthena's `quest` table.

  One row per `(char_id, quest_id)`. `count1..count3` mirror rAthena's fixed
  3-objective record (`MAX_QUEST_OBJECTIVES`); the in-memory quest log's
  `counts` list maps positionally onto them. `deadline` is `nil` for an
  unlimited quest. The `giver_*` columns are all `nil` when no giver is known.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Aesir.Commons.Models.Character

  @valid_states ~w(active inactive complete)

  @type t :: %__MODULE__{
          id: integer() | nil,
          char_id: integer() | nil,
          quest_id: integer() | nil,
          state: String.t() | nil,
          count1: integer() | nil,
          count2: integer() | nil,
          count3: integer() | nil,
          deadline: DateTime.t() | nil,
          giver_name: String.t() | nil,
          giver_map: String.t() | nil,
          giver_x: integer() | nil,
          giver_y: integer() | nil,
          character: Character.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "character_quests" do
    belongs_to :character, Character, foreign_key: :char_id

    field :quest_id, :integer
    field :state, :string, default: "active"
    field :count1, :integer, default: 0
    field :count2, :integer, default: 0
    field :count3, :integer, default: 0
    field :deadline, :utc_datetime
    field :giver_name, :string
    field :giver_map, :string
    field :giver_x, :integer
    field :giver_y, :integer

    timestamps()
  end

  @doc """
  Creates a changeset for a persisted character quest.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(quest, attrs) do
    quest
    |> cast(attrs, [
      :char_id,
      :quest_id,
      :state,
      :count1,
      :count2,
      :count3,
      :deadline,
      :giver_name,
      :giver_map,
      :giver_x,
      :giver_y
    ])
    |> validate_required([:char_id, :quest_id])
    |> validate_inclusion(:state, @valid_states)
    |> unique_constraint([:char_id, :quest_id])
    |> foreign_key_constraint(:char_id)
  end
end
