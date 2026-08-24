defmodule Aesir.ZoneServer.Guild.Position do
  @moduledoc """
  One of a guild's 20 position slots (0-19).

  Pure value derived from `Aesir.Commons.Models.GuildPosition`. `can_storage`
  gates access to the guild's shared storage; `tax` is carried for parity but
  still inert. Index 0 is always the guild master slot; index 19 is where new
  members join.
  """

  alias Aesir.Commons.Models.GuildPosition

  @default_count 20
  @master_index 0
  @newbie_index 19

  @enforce_keys [:index]
  defstruct index: nil, name: "", can_invite: false, can_expel: false, can_storage: false, tax: 0

  @type t() :: %__MODULE__{
          index: non_neg_integer(),
          name: String.t(),
          can_invite: boolean(),
          can_expel: boolean(),
          can_storage: boolean(),
          tax: non_neg_integer()
        }

  @doc "Builds a position from its persisted `GuildPosition` model row."
  @spec from_model(GuildPosition.t()) :: t()
  def from_model(%GuildPosition{} = model) do
    %__MODULE__{
      index: model.index,
      name: model.name || "",
      can_invite: model.can_invite,
      can_expel: model.can_expel,
      can_storage: model.can_storage,
      tax: model.tax
    }
  end

  @doc """
  The 20 default positions seeded on guild creation (rAthena
  `int_guild.cpp`): index 0 `"GuildMaster"` with invite+expel, index 19
  `"Newbie"` with no flags, indexes 1-18 blank with no flags.
  """
  @spec defaults() :: [t()]
  def defaults do
    for index <- 0..(@default_count - 1) do
      case index do
        @master_index ->
          %__MODULE__{index: index, name: "GuildMaster", can_invite: true, can_expel: true}

        @newbie_index ->
          %__MODULE__{index: index, name: "Newbie"}

        _ ->
          %__MODULE__{index: index, name: ""}
      end
    end
  end
end
