defmodule Aesir.ZoneServer.Unit.Session.Vitals do
  @moduledoc """
  Shared HP/SP clamp math for both unit types.

  Owns the three vitals mutations whose arithmetic used to be copy-pasted across
  the player and mob sessions: `heal/4` (HP up, ceiling `max_hp`), `drain_sp/4`
  (SP down, floor `0`) and `restore_sp/4` (SP up, ceiling `max_sp`). Each is
  parameterized by a `Unit.Session.Adapter` module so the clamp lives here once
  while the concrete state shape, client sync and persistence stay per-type.

  What deliberately stays out of here (the "honest share"): dead-unit guards
  live in the session dispatch clauses, since they differ by op and type (mob SP
  drain no-ops on a corpse, mob heal does not, players are ungated); and the
  player's combat heal keeps its received-heal-rate scaling in `HealthHandler`.

  Side effects run through the adapter in a fixed order — write, then optionally
  commit to the authoritative shared views, then notify watchers — so a
  committed registry snapshot precedes the wire notify, as the player path did
  before this converged. `commit:` is opt-in per call: the player ops pass it,
  the mob ops do not (mob heal/drain publish an HP broadcast but never touch the
  registry or a durable row, exactly as before).
  """

  alias Aesir.ZoneServer.Unit.Session.Adapter

  @type state :: Adapter.state()

  @typedoc """
  Per-call options.

  - `:commit` (default `false`) — when true, publish the change to the
    authoritative shared views (registry/party sync + durable persist) through
    the adapter's `commit/3`, scoped to the field this op touched.
  """
  @type opts :: [commit: boolean()]

  @doc """
  Raises HP by `amount`, clamped at `max_hp`. Non-positive amounts are a no-op.
  """
  @spec heal(state(), integer(), module(), opts()) :: state()
  def heal(state, amount, adapter, opts \\ [])

  def heal(state, amount, adapter, opts) when is_integer(amount) and amount > 0 do
    vitals = adapter.get_vitals(state)
    apply_change(state, adapter, %{hp: min(vitals.hp + amount, vitals.max_hp)}, [:hp], opts)
  end

  def heal(state, _amount, _adapter, _opts), do: state

  @doc """
  Drains `amount` SP, clamped at 0. Non-positive amounts are a no-op.
  """
  @spec drain_sp(state(), integer(), module(), opts()) :: state()
  def drain_sp(state, amount, adapter, opts \\ [])

  def drain_sp(state, amount, adapter, opts) when is_integer(amount) and amount > 0 do
    vitals = adapter.get_vitals(state)
    apply_change(state, adapter, %{sp: max(0, vitals.sp - amount)}, [:sp], opts)
  end

  def drain_sp(state, _amount, _adapter, _opts), do: state

  @doc """
  Restores `amount` SP, clamped at `max_sp`. Non-positive amounts are a no-op.
  """
  @spec restore_sp(state(), integer(), module(), opts()) :: state()
  def restore_sp(state, amount, adapter, opts \\ [])

  def restore_sp(state, amount, adapter, opts) when is_integer(amount) and amount > 0 do
    vitals = adapter.get_vitals(state)
    apply_change(state, adapter, %{sp: min(vitals.sp + amount, vitals.max_sp)}, [:sp], opts)
  end

  def restore_sp(state, _amount, _adapter, _opts), do: state

  @doc """
  Whether the unit currently holds at least `amount` SP.

  The affordability check for the all-or-nothing `try_consume_sp` path, which
  drains via `drain_sp/4` only once this returns true.
  """
  @spec can_pay_sp?(state(), module(), non_neg_integer()) :: boolean()
  def can_pay_sp?(state, adapter, amount) do
    adapter.get_vitals(state).sp >= amount
  end

  defp apply_change(prev, adapter, update, fields, opts) do
    updated = adapter.put_vitals(prev, update)

    committed =
      if Keyword.get(opts, :commit, false),
        do: adapter.commit(prev, updated, fields),
        else: updated

    adapter.notify_vitals(committed, fields)
    committed
  end
end
