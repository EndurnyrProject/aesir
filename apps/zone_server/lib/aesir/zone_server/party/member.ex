defmodule Aesir.ZoneServer.Party.Member do
  @moduledoc """
  Per-member snapshot carried inside a `Aesir.ZoneServer.Party.State` entry.

  Mirrors the durable membership on `characters.party_id` plus the runtime
  presence fields (`online`, `map_name`) pushed by each member's
  `PlayerSession`.
  """

  alias Aesir.Commons.Models.Character

  @enforce_keys [:char_id, :name, :base_level, :online]
  defstruct char_id: nil,
            name: nil,
            job_id: 0,
            base_level: nil,
            hp: 0,
            max_hp: 0,
            sp: 0,
            max_sp: 0,
            ap: 0,
            max_ap: 0,
            online: nil,
            map_name: nil

  @type t() :: %__MODULE__{
          char_id: non_neg_integer(),
          name: String.t(),
          job_id: non_neg_integer(),
          base_level: non_neg_integer(),
          hp: non_neg_integer(),
          max_hp: non_neg_integer(),
          sp: non_neg_integer(),
          max_sp: non_neg_integer(),
          ap: non_neg_integer(),
          max_ap: non_neg_integer(),
          online: boolean(),
          map_name: String.t() | nil
        }

  @doc """
  Builds a member snapshot from its minimal runtime identity and presence.
  """
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

  @doc """
  Builds a member snapshot from persisted character state.
  """
  @spec from_character(Character.t(), boolean()) :: t()
  def from_character(%Character{} = character, online \\ false) do
    %__MODULE__{
      char_id: character.id,
      name: character.name,
      job_id: character.class || 0,
      base_level: character.base_level || 1,
      hp: character.hp || 0,
      max_hp: character.max_hp || 0,
      sp: character.sp || 0,
      max_sp: character.max_sp || 0,
      ap: character.ap || 0,
      max_ap: character.max_ap || 0,
      online: online,
      map_name: character.last_map
    }
  end
end
