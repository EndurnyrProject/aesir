defmodule Aesir.ZoneServer.Mmo.QuestManagement.QuestDefinition do
  @moduledoc """
  Static quest definition (the rAthena `quest_db` record).

  Loaded as data from `priv/db/<mode>/quests/*.yml` into `:persistent_term`;
  never a per-quest module. `time_limit` is carried through unused this
  iteration. Objectives and drops are read on every monster kill
  (`Unit.Player.QuestLog`).
  """

  @typedoc """
  A single hunt objective. With `mob_id` it counts kills of that monster only.
  Without it, a kill counts when it passes every present filter
  (`min_level`/`max_level`/`race`/`size`/`element`/`map`/`mobs_allowed`).
  """
  @type target :: %{
          optional(:mob_id) => integer(),
          optional(:min_level) => integer() | nil,
          optional(:max_level) => integer() | nil,
          optional(:race) => String.t() | nil,
          optional(:size) => String.t() | nil,
          optional(:element) => String.t() | nil,
          optional(:map) => String.t() | nil,
          optional(:mobs_allowed) => [integer()] | nil,
          required(:count) => integer()
        }

  @typedoc """
  An extra item a kill grants while the quest is not complete. `mob_id` `0`
  means any monster; `rate` is out of 10000; `count` is data only, since the
  grant is always one item.
  """
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
