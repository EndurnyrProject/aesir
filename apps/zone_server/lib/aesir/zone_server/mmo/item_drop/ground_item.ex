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
          random_options: ItemOptions.t()
        }

  @typedoc """
  An item to place on the ground at a cell: the plain item, or the item with
  its random options.
  """
  @type drop_entry ::
          {non_neg_integer(), pos_integer(), integer(), integer(), boolean()}
          | {non_neg_integer(), pos_integer(), integer(), integer(), boolean(), ItemOptions.t()}

  @doc """
  Builds a `GroundItem`, generating a fresh unique `id`, a random sub-cell
  position, and stamping `dropped_at` with the current monotonic time in
  milliseconds. Pass `owners:` and `unlock_at:` to attach an immutable ownership
  stamp; omit both for a public item. `random_options:` carries the item's
  option slots.
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
      random_options: Keyword.get(opts, :random_options, [])
    }
  end

  @doc "Returns the drop entry that puts `item` back on its own cell."
  @spec drop_entry(t()) :: drop_entry()
  def drop_entry(%__MODULE__{} = item),
    do: entry(item.nameid, item.amount, item.x, item.y, item.identified, item.random_options)

  @doc "Returns the drop entry of an item at a cell, with its options only when it has any."
  @spec entry(
          non_neg_integer(),
          pos_integer(),
          integer(),
          integer(),
          boolean(),
          ItemOptions.t()
        ) :: drop_entry()
  def entry(nameid, amount, x, y, identified, []), do: {nameid, amount, x, y, identified}

  def entry(nameid, amount, x, y, identified, options),
    do: {nameid, amount, x, y, identified, options}

  @doc """
  Returns the inventory grant attributes of picking `item` up: its identify
  flag, with its random options when it has any.
  """
  @spec grant_attrs(t()) :: boolean() | map()
  def grant_attrs(%__MODULE__{random_options: []} = item), do: item.identified

  def grant_attrs(%__MODULE__{} = item),
    do: %{identify: if(item.identified, do: 1, else: 0), random_options: item.random_options}

  # Mirrors rAthena's map_addflooritem, which scatters stacked drops across a
  # 4x4 sub-grid within the cell: each axis is one of {3, 6, 9, 12}.
  @spec random_sub_cell() :: non_neg_integer()
  defp random_sub_cell, do: (:rand.uniform(4) - 1) * 3 + 3
end
