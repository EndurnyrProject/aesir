defmodule Aesir.ZoneServer.Mmo.ItemDrop.GroundItem do
  @moduledoc """
  Immutable data for a single item lying on the ground.

  The `id` is a process-unique, monotonically increasing positive integer used
  as the ground handle (distinct from an inventory slot); `dropped_at` is a
  monotonic millisecond stamp used by the expiry sweep. `x`/`y` are the cell on
  the owning map, which is keyed elsewhere by the clean map name (no `.gat`).

  `sub_x`/`sub_y` are the sub-cell offset the client renders the sprite at within
  the tile, so items stacked on one cell don't draw exactly on top of each other.
  `owners` and `unlock_at` form an immutable ownership stamp; when both are
  `nil`, the item is public. `random_options` are the item's option slots,
  kept from its drop to whoever picks it up.
  """

  alias Aesir.Commons.Models.ItemOptions

  @enforce_keys [:id, :nameid, :amount, :x, :y, :sub_x, :sub_y, :identified, :dropped_at]
  defstruct [
    :id,
    :nameid,
    :amount,
    :x,
    :y,
    :sub_x,
    :sub_y,
    :identified,
    :dropped_at,
    owners: nil,
    unlock_at: nil,
    refine: 0,
    attribute: 0,
    cards: [0, 0, 0, 0],
    random_options: []
  ]

  @typedoc """
  The first, second, and third loot-owner character IDs, or `nil` for a public item.
  """
  @type owners() :: {integer() | nil, integer() | nil, integer() | nil} | nil

  @typedoc """
  Absolute monotonic-millisecond deadlines when the second owner, third owner,
  and public pickup unlock.
  """
  @type unlock_at() :: {integer(), integer(), integer()} | nil

  @type t() :: %__MODULE__{
          id: pos_integer(),
          nameid: non_neg_integer(),
          amount: pos_integer(),
          x: non_neg_integer(),
          y: non_neg_integer(),
          sub_x: non_neg_integer(),
          sub_y: non_neg_integer(),
          identified: boolean(),
          dropped_at: integer(),
          owners: owners(),
          unlock_at: unlock_at(),
          refine: non_neg_integer(),
          attribute: non_neg_integer(),
          cards: [integer()],
          random_options: ItemOptions.t()
        }

  @typedoc """
  The attributes a ground item carries beyond its id and identify flag, when
  they are not the defaults (unrefined, no attribute, no cards, no options).
  """
  @type extras :: %{
          optional(:refine) => non_neg_integer(),
          optional(:attribute) => non_neg_integer(),
          optional(:cards) => [integer()],
          optional(:random_options) => ItemOptions.t()
        }

  @typedoc """
  An item to place on the ground at a cell: the plain item, or the item with
  its non-default attributes.
  """
  @type drop_entry ::
          {non_neg_integer(), pos_integer(), integer(), integer(), boolean()}
          | {non_neg_integer(), pos_integer(), integer(), integer(), boolean(), extras()}

  @doc """
  Builds a `GroundItem`, generating a fresh unique `id`, a random sub-cell
  position, and stamping `dropped_at` with the current monotonic time in
  milliseconds. Pass `owners:` and `unlock_at:` to attach an immutable ownership
  stamp; omit both for a public item. `refine:`, `attribute:`, `cards:` and
  `random_options:` carry the item's attributes.
  """
  @spec new(
          non_neg_integer(),
          pos_integer(),
          non_neg_integer(),
          non_neg_integer(),
          boolean(),
          keyword()
        ) :: t()
  def new(nameid, amount, x, y, identified \\ true, opts \\ []) do
    %__MODULE__{
      id: :erlang.unique_integer([:positive, :monotonic]),
      nameid: nameid,
      amount: amount,
      x: x,
      y: y,
      sub_x: random_sub_cell(),
      sub_y: random_sub_cell(),
      identified: identified,
      dropped_at: System.monotonic_time(:millisecond),
      owners: Keyword.get(opts, :owners),
      unlock_at: Keyword.get(opts, :unlock_at),
      refine: Keyword.get(opts, :refine, 0),
      attribute: Keyword.get(opts, :attribute, 0),
      cards: Keyword.get(opts, :cards, [0, 0, 0, 0]),
      random_options: Keyword.get(opts, :random_options, [])
    }
  end

  @doc "Returns the drop entry that puts `item` back on its own cell."
  @spec drop_entry(t()) :: drop_entry()
  def drop_entry(%__MODULE__{} = item),
    do: entry(item.nameid, item.amount, item.x, item.y, item.identified, extras(item))

  @doc """
  Returns the drop entry of an item at a cell, carrying `extras` (or just
  random options) only when they differ from the defaults.
  """
  @spec entry(
          non_neg_integer(),
          pos_integer(),
          integer(),
          integer(),
          boolean(),
          extras() | ItemOptions.t()
        ) :: drop_entry()
  def entry(nameid, amount, x, y, identified, options) when is_list(options),
    do: entry(nameid, amount, x, y, identified, %{random_options: options})

  def entry(nameid, amount, x, y, identified, extras) do
    case non_default(extras) do
      empty when empty == %{} -> {nameid, amount, x, y, identified}
      extras -> {nameid, amount, x, y, identified, extras}
    end
  end

  @doc """
  Returns the inventory grant attributes of picking `item` up: its identify
  flag, with its other attributes when it has any.
  """
  @spec grant_attrs(t()) :: boolean() | map()
  def grant_attrs(%__MODULE__{} = item) do
    case extras(item) do
      empty when empty == %{} ->
        item.identified

      extras ->
        {cards, extras} = Map.pop(extras, :cards, [0, 0, 0, 0])
        [c0, c1, c2, c3] = cards

        Map.merge(extras, %{
          identify: if(item.identified, do: 1, else: 0),
          card0: c0,
          card1: c1,
          card2: c2,
          card3: c3
        })
    end
  end

  @defaults %{refine: 0, attribute: 0, cards: [0, 0, 0, 0], random_options: []}

  defp extras(item), do: non_default(Map.take(item, Map.keys(@defaults)))

  defp non_default(extras), do: Map.reject(extras, fn {key, value} -> @defaults[key] == value end)

  # Mirrors rAthena's map_addflooritem, which scatters stacked drops across a
  # 4x4 sub-grid within the cell: each axis is one of {3, 6, 9, 12}.
  @spec random_sub_cell() :: non_neg_integer()
  defp random_sub_cell, do: (:rand.uniform(4) - 1) * 3 + 3
end
