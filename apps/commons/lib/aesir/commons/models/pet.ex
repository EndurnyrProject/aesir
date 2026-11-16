defmodule Aesir.Commons.Models.Pet do
  @moduledoc "Durable state for a pet."

  use Ecto.Schema
  import Ecto.Changeset

  @typedoc "A persisted pet row (rAthena `pet` table); the id is the pet id."
  @type t :: %__MODULE__{
          id: integer() | nil,
          class: integer() | nil,
          name: String.t() | nil,
          account_id: integer() | nil,
          char_id: integer() | nil,
          level: integer() | nil,
          egg_id: integer() | nil,
          equip: integer() | nil,
          intimate: integer() | nil,
          hungry: integer() | nil,
          rename_flag: integer() | nil,
          incubate: integer() | nil,
          autofeed: boolean() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "pets" do
    field :class, :integer
    field :name, :string
    field :account_id, :integer
    field :char_id, :integer
    field :level, :integer
    field :egg_id, :integer
    field :equip, :integer, default: 0
    field :intimate, :integer
    field :hungry, :integer
    field :rename_flag, :integer, default: 0
    field :incubate, :integer, default: 1
    field :autofeed, :boolean, default: false
    timestamps()
  end

  @doc "Creates a changeset for a persisted pet."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(pet, attrs) do
    pet
    |> cast(attrs, [
      :class,
      :name,
      :account_id,
      :char_id,
      :level,
      :egg_id,
      :equip,
      :intimate,
      :hungry,
      :rename_flag,
      :incubate,
      :autofeed
    ])
    |> validate_required([
      :class,
      :name,
      :account_id,
      :char_id,
      :level,
      :egg_id,
      :equip,
      :intimate,
      :hungry,
      :rename_flag,
      :incubate,
      :autofeed
    ])
    |> validate_length(:name, max: 24)
    |> validate_number(:intimate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1000)
    |> validate_number(:hungry, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:rename_flag, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:incubate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end
