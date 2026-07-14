defmodule Aesir.Commons.Models.GuildPosition do
  @moduledoc """
  A single guild position slot (rAthena's 0-19 `guild_position` table).

  Keyed by `{guild_id, index}`. Index 0 is always the guild master slot;
  index 19 is where new members join. `can_storage` and `tax` are tracked
  for parity with rAthena but are inert in phase 1 (no guild storage/tax
  mechanics yet).
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          guild_id: integer() | nil,
          index: integer() | nil,
          name: String.t() | nil,
          can_invite: boolean(),
          can_expel: boolean(),
          can_storage: boolean(),
          tax: integer()
        }

  @primary_key false
  schema "guild_positions" do
    field :guild_id, :integer, primary_key: true
    field :index, :integer, primary_key: true
    field :name, :string
    field :can_invite, :boolean, default: false
    field :can_expel, :boolean, default: false
    field :can_storage, :boolean, default: false
    field :tax, :integer, default: 0
  end

  @doc """
  Creates a changeset for a guild position.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild_position, attrs) do
    guild_position
    |> cast(attrs, [:guild_id, :index, :name, :can_invite, :can_expel, :can_storage, :tax])
    |> validate_required([:guild_id, :index])
    |> validate_inclusion(:index, 0..19)
    |> unique_constraint([:guild_id, :index], name: :guild_positions_pkey)
  end
end
