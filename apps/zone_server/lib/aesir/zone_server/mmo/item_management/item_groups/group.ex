defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry do
  @moduledoc "An item entry in an item-group subgroup."

  @enforce_keys [:item_id]
  defstruct item_id: nil,
            rate: 0,
            amount: 1,
            identify?: false,
            duration_min: 0,
            bound: nil,
            unique_id?: false,
            refine_min: 0,
            refine_max: 0,
            grade_min: 0,
            grade_max: 0,
            named?: false,
            announced?: false

  @type t() :: %__MODULE__{
          item_id: pos_integer(),
          rate: non_neg_integer(),
          amount: pos_integer(),
          identify?: boolean(),
          duration_min: non_neg_integer(),
          bound: atom() | nil,
          unique_id?: boolean(),
          refine_min: 0..20,
          refine_max: 0..20,
          grade_min: non_neg_integer(),
          grade_max: non_neg_integer(),
          named?: boolean(),
          announced?: boolean()
        }
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup do
  @moduledoc "A numbered item-group subgroup and its selection algorithm."

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry

  @enforce_keys [:number, :algorithm, :entries]
  defstruct number: nil, algorithm: nil, entries: []

  @type algorithm() :: :random | :all | :shared_pool

  @type t() :: %__MODULE__{
          number: non_neg_integer(),
          algorithm: algorithm(),
          entries: [Entry.t()]
        }
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group do
  @moduledoc "A named item group and the shared grant shape produced from it."

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  @enforce_keys [:key, :subgroups]
  defstruct key: nil, subgroups: []

  @type t() :: %__MODULE__{
          key: atom(),
          subgroups: [SubGroup.t()]
        }

  @typedoc "A concrete item grant produced by an item-group roll."
  @type grant() :: %{
          optional(:group_key) => atom(),
          item_id: pos_integer(),
          amount: pos_integer(),
          identify?: boolean(),
          refine: 0..20,
          grade: non_neg_integer(),
          bound: atom() | nil,
          unique_id?: boolean(),
          duration_min: non_neg_integer(),
          named?: boolean(),
          announced?: boolean(),
          drawn: {non_neg_integer(), [pos_integer()]} | nil
        }
end
