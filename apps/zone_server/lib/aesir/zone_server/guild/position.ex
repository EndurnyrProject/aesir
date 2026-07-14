defmodule Aesir.ZoneServer.Guild.Position do
  @moduledoc """
  One of a guild's 20 position slots (rAthena's `guild_position` 0-19).

  Pure value derived from `Aesir.Commons.Models.GuildPosition`. `can_storage`
  and `tax` are carried for parity with rAthena but inert in phase 1. Index 0
  is always the guild master slot; index 19 is where new members join.
  """
  use TypedStruct

  alias Aesir.Commons.Models.GuildPosition

  @default_count 20
  @master_index 0
  @newbie_index 19

  typedstruct do
    field :index, non_neg_integer(), enforce: true
    field :name, String.t(), default: ""
    field :can_invite, boolean(), default: false
    field :can_expel, boolean(), default: false
    field :can_storage, boolean(), default: false
    field :tax, non_neg_integer(), default: 0
  end

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
