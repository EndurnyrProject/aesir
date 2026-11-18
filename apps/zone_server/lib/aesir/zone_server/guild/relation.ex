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

  use TypedStruct

  @type kind :: :ally | :antagonist

  typedstruct do
    field :guild_id, pos_integer(), enforce: true
    field :name, String.t(), enforce: true
    field :kind, kind(), enforce: true
    field :level, non_neg_integer(), default: 0
    field :member_count, non_neg_integer(), default: 0
    field :master_name, String.t(), default: ""
    field :emblem_id, non_neg_integer(), default: 0
  end
end
