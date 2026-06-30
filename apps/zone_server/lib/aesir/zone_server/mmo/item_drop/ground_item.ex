defmodule Aesir.ZoneServer.Mmo.ItemDrop.GroundItem do
  @moduledoc """
  Immutable data for a single item lying on the ground.

  The `id` is a process-unique, monotonically increasing positive integer used
  as the ground handle (distinct from an inventory slot); `dropped_at` is a
  monotonic millisecond stamp used by the expiry sweep. `x`/`y` are the cell on
  the owning map, which is keyed elsewhere by the clean map name (no `.gat`).
  """

  use TypedStruct

  typedstruct enforce: true do
    field :id, pos_integer()
    field :nameid, non_neg_integer()
    field :amount, pos_integer()
    field :x, non_neg_integer()
    field :y, non_neg_integer()
    field :identified, boolean()
    field :dropped_at, integer()
  end

  @doc """
  Builds a `GroundItem`, generating a fresh unique `id` and stamping
  `dropped_at` with the current monotonic time in milliseconds.
  """
  @spec new(non_neg_integer(), pos_integer(), non_neg_integer(), non_neg_integer(), boolean()) ::
          t()
  def new(nameid, amount, x, y, identified \\ true) do
    %__MODULE__{
      id: :erlang.unique_integer([:positive, :monotonic]),
      nameid: nameid,
      amount: amount,
      x: x,
      y: y,
      identified: identified,
      dropped_at: System.monotonic_time(:millisecond)
    }
  end
end
