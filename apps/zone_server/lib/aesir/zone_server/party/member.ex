defmodule Aesir.ZoneServer.Party.Member do
  @moduledoc """
  Per-member snapshot carried inside a `Aesir.ZoneServer.Party.State` entry.

  Mirrors the durable membership on `characters.party_id` plus the runtime
  presence fields (`online`, `map_name`) pushed by each member's
  `PlayerSession`.
  """
  use TypedStruct

  typedstruct do
    field :char_id, non_neg_integer(), enforce: true
    field :name, String.t(), enforce: true
    field :base_level, non_neg_integer(), enforce: true
    field :online, boolean(), enforce: true
    field :map_name, String.t()
  end

  @spec new(non_neg_integer(), String.t(), non_neg_integer(), boolean(), String.t() | nil) ::
          t()
  def new(char_id, name, base_level, online, map_name \\ nil) do
    %__MODULE__{
      char_id: char_id,
      name: name,
      base_level: base_level,
      online: online,
      map_name: map_name
    }
  end
end
