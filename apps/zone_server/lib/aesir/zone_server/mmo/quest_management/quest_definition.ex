defmodule Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition do
  @moduledoc """
  Static quest definition (the rAthena `quest_db` record).

  Loaded as data from `priv/db/quests/*.yml` into `:persistent_term`; never a
  per-quest module. `time_limit`, the target filter fields beyond `mob_id`/
  `count`, and `drops` are carried through unused this iteration - only exact-mob
  hunt counters are interpreted so far.
  """
  use TypedStruct

  @typedoc """
  A single hunt objective: exact mob kill count, plus dormant filters
  (`min_level`/`max_level`/`race`/`size`/`element`/`map`/`mobs_allowed`).
  """
  @type target :: %{
          mob_id: integer(),
          count: integer(),
          min_level: integer() | nil,
          max_level: integer() | nil,
          race: String.t() | nil,
          size: String.t() | nil,
          element: String.t() | nil,
          map: String.t() | nil,
          mobs_allowed: [integer()] | nil
        }

  @typedoc "A dormant bonus item drop tied to a quest kill."
  @type drop :: %{
          mob_id: integer(),
          item_id: integer(),
          count: integer(),
          rate: integer()
        }

  typedstruct do
    field :id, integer(), enforce: true
    field :title, String.t(), enforce: true
    field :time_limit, String.t() | nil, default: nil
    field :targets, [target()], default: []
    field :drops, [drop()], default: []
  end
end
