defmodule Aesir.Commons.Models.Homunculus do
  @moduledoc """
  Durable state for a character-owned Homunculus.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Aesir.Commons.Models.Character

  @lifecycles ~w(active rested dead)
  @bounded_map_fields [:learned_skills, :cooldowns, :ai_config]
  @resource_fields [:exp, :skill_points, :hp, :max_hp, :sp, :max_sp, :active_remaining_ms]

  @type t :: %__MODULE__{
          id: integer() | nil,
          character_id: integer() | nil,
          character: Character.t() | Ecto.Association.NotLoaded.t(),
          class_id: integer() | nil,
          name: String.t() | nil,
          rename_available: boolean() | nil,
          lifecycle: String.t() | nil,
          level: integer() | nil,
          exp: integer() | nil,
          skill_points: integer() | nil,
          hp: integer() | nil,
          max_hp: integer() | nil,
          sp: integer() | nil,
          max_sp: integer() | nil,
          str: integer() | nil,
          agi: integer() | nil,
          vit: integer() | nil,
          int: integer() | nil,
          dex: integer() | nil,
          luk: integer() | nil,
          hunger: integer() | nil,
          intimacy_hundredths: integer() | nil,
          active_remaining_ms: integer() | nil,
          learned_skills: map() | nil,
          cooldowns: map() | nil,
          ai_config: map() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "homunculi" do
    belongs_to :character, Character

    field :class_id, :integer
    field :name, :string
    field :rename_available, :boolean, default: true
    field :lifecycle, :string, default: "active"
    field :level, :integer, default: 1
    field :exp, :integer, default: 0
    field :skill_points, :integer, default: 0
    field :hp, :integer, default: 0
    field :max_hp, :integer, default: 0
    field :sp, :integer, default: 0
    field :max_sp, :integer, default: 0
    field :str, :integer, default: 0
    field :agi, :integer, default: 0
    field :vit, :integer, default: 0
    field :int, :integer, default: 0
    field :dex, :integer, default: 0
    field :luk, :integer, default: 0
    field :hunger, :integer, default: 32
    field :intimacy_hundredths, :integer, default: 2100
    field :active_remaining_ms, :integer, default: 1_800_000
    field :learned_skills, :map, default: %{}
    field :cooldowns, :map, default: %{}
    field :ai_config, :map, default: %{}

    timestamps()
  end

  @doc """
  Creates a changeset for a persisted Homunculus.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(homunculus, attrs) do
    homunculus
    |> cast(attrs, [
      :character_id,
      :class_id,
      :name,
      :rename_available,
      :lifecycle,
      :level,
      :exp,
      :skill_points,
      :hp,
      :max_hp,
      :sp,
      :max_sp,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :hunger,
      :intimacy_hundredths,
      :active_remaining_ms,
      :learned_skills,
      :cooldowns,
      :ai_config
    ])
    |> validate_required([:character_id, :class_id, :name])
    |> validate_length(:name, min: 1, max: 23)
    |> validate_inclusion(:lifecycle, @lifecycles)
    |> validate_number(:level, greater_than_or_equal_to: 1, less_than_or_equal_to: 99)
    |> validate_number(:hunger, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:intimacy_hundredths,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100_000
    )
    |> validate_non_negative(@resource_fields)
    |> validate_bounded_maps()
    |> unique_constraint(:character_id)
    |> foreign_key_constraint(:character_id)
    |> check_constraint(:lifecycle, name: :homunculi_lifecycle_check)
    |> check_constraint(:level, name: :homunculi_level_check)
    |> check_constraint(:hunger, name: :homunculi_hunger_check)
    |> check_constraint(:intimacy_hundredths, name: :homunculi_intimacy_hundredths_check)
    |> check_constraint(:exp, name: :homunculi_resources_non_negative)
    |> check_constraint(:learned_skills, name: :homunculi_learned_skills_is_object)
    |> check_constraint(:cooldowns, name: :homunculi_cooldowns_is_object)
    |> check_constraint(:ai_config, name: :homunculi_ai_config_is_object)
  end

  defp validate_non_negative(changeset, fields) do
    Enum.reduce(fields, changeset, fn field, changeset ->
      validate_number(changeset, field, greater_than_or_equal_to: 0)
    end)
  end

  defp validate_bounded_maps(changeset) do
    Enum.reduce(@bounded_map_fields, changeset, &validate_bounded_map(&2, &1))
  end

  defp validate_bounded_map(changeset, field) do
    validate_change(changeset, field, fn ^field, value -> bounded_map_errors(field, value) end)
  end

  defp bounded_map_errors(_field, value) when is_map(value) and map_size(value) <= 64, do: []

  defp bounded_map_errors(field, _value) do
    [{field, "must be a map with at most 64 entries"}]
  end
end
