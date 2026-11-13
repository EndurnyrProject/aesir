defmodule Aesir.Commons.Models.Guild do
  @moduledoc """
  Guild model — persistence source of truth for guild existence, master,
  emblem, and notice.

  Membership itself lives on the existing `characters.guild_id` /
  `characters.guild_position` columns; this schema only tracks the guild's
  name, master, emblem, and notice board. `notice_author` and
  `notice_posted_at` record who last edited the notice and when; both are
  `nil` until the first edit.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          master_char_id: integer() | nil,
          emblem_id: integer(),
          emblem_data: binary() | nil,
          notice_subject: String.t() | nil,
          notice_body: String.t() | nil,
          notice_author: String.t() | nil,
          notice_posted_at: DateTime.t() | nil,
          level: pos_integer(),
          exp: non_neg_integer(),
          skill_points: non_neg_integer(),
          learned_skills: map(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "guilds" do
    field :name, :string
    field :master_char_id, :integer
    field :emblem_id, :integer, default: 0
    field :emblem_data, :binary
    field :notice_subject, :string
    field :notice_body, :string
    field :notice_author, :string
    field :notice_posted_at, :utc_datetime
    field :level, :integer, default: 1
    field :exp, :integer, default: 0
    field :skill_points, :integer, default: 0
    field :learned_skills, :map, default: %{}

    timestamps()
  end

  @doc """
  Creates a changeset for a guild.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild, attrs) do
    guild
    |> cast(attrs, [
      :name,
      :master_char_id,
      :emblem_id,
      :emblem_data,
      :notice_subject,
      :notice_body,
      :notice_author,
      :notice_posted_at,
      :level,
      :exp,
      :skill_points,
      :learned_skills
    ])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :master_char_id, :level, :exp, :skill_points, :learned_skills])
    |> validate_length(:name, min: 1)
    |> validate_number(:level, greater_than_or_equal_to: 1, less_than_or_equal_to: 50)
    |> validate_number(:exp, greater_than_or_equal_to: 0)
    |> validate_number(:skill_points, greater_than_or_equal_to: 0)
    |> unique_constraint(:name)
  end

  @doc """
  Builds a changeset for a new guild from the given attrs.
  """
  @spec new(map()) :: Ecto.Changeset.t()
  def new(attrs \\ %{}) do
    changeset(%__MODULE__{}, attrs)
  end
end
