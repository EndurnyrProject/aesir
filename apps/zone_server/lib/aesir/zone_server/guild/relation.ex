defmodule Aesir.ZoneServer.Guild.Relation do
  @moduledoc """
  Per-relation snapshot carried inside a `Aesir.ZoneServer.Guild.State` entry.

  A directed relation toward another guild: `:ally` or `:antagonist`. Mirrors
  a row of `Aesir.Commons.Models.GuildRelation`, keyed by `guild_id` on the
  owning guild's `State.relations` map.
  """

  @enforce_keys [:guild_id, :name, :kind]
  defstruct guild_id: nil,
            name: nil,
            kind: nil

  @type kind :: :ally | :antagonist

  @type t() :: %__MODULE__{
          guild_id: pos_integer(),
          name: String.t(),
          kind: kind()
        }
end
