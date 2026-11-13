defmodule Aesir.ZoneServer.Guild.Relation do
  @moduledoc """
  Per-relation snapshot carried inside a `Aesir.ZoneServer.Guild.State` entry.

  A directed relation toward another guild: `:ally` or `:antagonist`. Mirrors
  a row of `Aesir.Commons.Models.GuildRelation`, keyed by `guild_id` on the
  owning guild's `State.relations` map.

  `level`, `member_count`, `master_name` and `emblem_id` describe the other
  guild as its rows stood when the relation map was loaded. They are what a
  `GuildInfo` shows while the other guild has no live entry; a live entry is
  always preferred (`Aesir.ZoneServer.Guild.View`).
  """

  @enforce_keys [:guild_id, :name, :kind]
  defstruct guild_id: nil,
            name: nil,
            kind: nil,
            level: 0,
            member_count: 0,
            master_name: "",
            emblem_id: 0

  @type kind :: :ally | :antagonist

  @type t() :: %__MODULE__{
          guild_id: pos_integer(),
          name: String.t(),
          kind: kind(),
          level: non_neg_integer(),
          member_count: non_neg_integer(),
          master_name: String.t(),
          emblem_id: non_neg_integer()
        }
end
