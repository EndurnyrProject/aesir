defmodule Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition do
  @moduledoc """
  Static quest definition (the rAthena `quest_db` record).

  Loaded as data from `priv/db/re/quests/*.yml` into `:persistent_term`; never a
  per-quest module. `time_limit`, the target filter fields beyond `mob_id`/
  `count`, and `drops` are carried through unused this iteration - only exact-mob
  hunt counters are interpreted so far.
  """

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

  @enforce_keys [:id, :title]
  defstruct id: nil, title: nil, time_limit: nil, targets: [], drops: []

  @type t() :: %__MODULE__{
          id: integer(),
          title: String.t(),
          time_limit: String.t() | nil,
          targets: [target()],
          drops: [drop()]
        }
end
