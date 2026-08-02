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
  `nil`, the item is public.
  """

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
    unlock_at: nil
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
          unlock_at: unlock_at()
        }

  @doc """
  Builds a `GroundItem`, generating a fresh unique `id`, a random sub-cell
  position, and stamping `dropped_at` with the current monotonic time in
  milliseconds. Pass `owners:` and `unlock_at:` to attach an immutable ownership
  stamp; omit both for a public item.
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
      unlock_at: Keyword.get(opts, :unlock_at)
    }
  end

  # Mirrors rAthena's map_addflooritem, which scatters stacked drops across a
  # 4x4 sub-grid within the cell: each axis is one of {3, 6, 9, 12}.
  @spec random_sub_cell() :: non_neg_integer()
  defp random_sub_cell, do: (:rand.uniform(4) - 1) * 3 + 3
end
