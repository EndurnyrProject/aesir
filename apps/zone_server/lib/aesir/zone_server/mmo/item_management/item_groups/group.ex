defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry do
  @moduledoc "An item entry in an item-group subgroup."

  use TypedStruct

  @typedoc "An item entry and its grant attributes."
  typedstruct enforce: true do
    field :item_id, pos_integer()
    field :rate, non_neg_integer(), default: 0
    field :amount, pos_integer(), default: 1
    field :identify?, boolean(), default: false
    field :duration_min, non_neg_integer(), default: 0
    field :bound, atom() | nil, default: nil
    field :unique_id?, boolean(), default: false
    field :refine_min, 0..20, default: 0
    field :refine_max, 0..20, default: 0
    field :grade_min, non_neg_integer(), default: 0
    field :grade_max, non_neg_integer(), default: 0
    field :named?, boolean(), default: false
    field :announced?, boolean(), default: false
    field :stacked?, boolean(), default: true
    field :random_option_group, pos_integer() | nil, default: nil
  end
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup do
  @moduledoc "A numbered item-group subgroup and its selection algorithm."

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Entry

  @type algorithm() :: :random | :all | :shared_pool

  @typedoc "A numbered subgroup and its entries."
  typedstruct enforce: true do
    field :number, non_neg_integer()
    field :algorithm, algorithm()
    field :entries, [Entry.t()]
  end
end

defmodule Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.Group do
  @moduledoc "A named item group and the shared grant shape produced from it."

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups.SubGroup

  @typedoc "A named item group and its subgroups."
  typedstruct enforce: true do
    field :key, atom()
    field :subgroups, [SubGroup.t()]
  end

  @typedoc "A concrete item grant produced by an item-group roll."
  @type grant() :: %{
          optional(:group_key) => atom(),
          optional(:random_option_group) => pos_integer() | nil,
          item_id: pos_integer(),
          amount: pos_integer(),
          identify?: boolean(),
          refine: 0..20,
          grade: non_neg_integer(),
          refine_min: 0..20,
          refine_max: 0..20,
          grade_min: non_neg_integer(),
          grade_max: non_neg_integer(),
          bound: atom() | nil,
          unique_id?: boolean(),
          duration_min: non_neg_integer(),
          named?: boolean(),
          announced?: boolean(),
          stacked?: boolean(),
          drawn: {non_neg_integer(), [pos_integer()]} | nil
        }
end
