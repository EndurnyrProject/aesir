defmodule Aesir.Commons.Models.GuildPosition do
  @moduledoc """
  A single guild position slot (0-19).

  Keyed by `{guild_id, index}`. Index 0 is always the guild master slot;
  index 19 is where new members join. `can_storage` gates access to the guild's
  shared storage, `can_notice` editing the notice, and `can_relations` managing
  alliances and antagonists; `tax` is the share of base EXP its holders pay to
  the guild.
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
          can_notice: boolean(),
          can_relations: boolean(),
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
    field :can_notice, :boolean, default: false
    field :can_relations, :boolean, default: false
    field :tax, :integer, default: 0
  end

  @doc """
  Creates a changeset for a guild position.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(guild_position, attrs) do
    guild_position
    |> cast(attrs, [
      :guild_id,
      :index,
      :name,
      :can_invite,
      :can_expel,
      :can_storage,
      :can_notice,
      :can_relations,
      :tax
    ])
    |> validate_required([:guild_id, :index])
    |> validate_inclusion(:index, 0..19)
    |> unique_constraint([:guild_id, :index], name: :guild_positions_pkey)
  end
end
